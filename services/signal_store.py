"""Single-owner SQLite history. Every visible change is emitted after COMMIT."""
from contextlib import contextmanager
import base64
import json
import os
from pathlib import Path
import sqlite3
import time
import uuid
import signal_replies
import signal_receipts
import signal_interactions
import signal_retention
import signal_directory
from signal_media import Media, MEDIA_CAPABILITIES, filename

from signal_events import digest, group_id, identifier, integer, message_fingerprint, normalize, service_id, text
from signal_paths import private_file
from signal_transport import Failure

SCHEMA_VERSION = 7
PENDING_TTL = 7 * 86400 * 1000
OUTBOX_TTL = 86400 * 1000  # Unconfirmed content is staging, not an eternal archive.
PAGE_BYTES = 512 * 1024
CAPABILITIES = ["conversations.page", "messages.page", "message.get", "conversation.open",
                "conversation.get", "conversation.preferences", "message.send", "draft.get", "draft.set", "operation.status",
                "operation.cancel", "operation.retry", "reply.draft.get", "reply.draft.set", "conversation.notifications", "messages.read", "message.edit", "message.react", "message.delete", "conversation.expiration", "typing.set"] + MEDIA_CAPABILITIES


def new_id():
    return str(uuid.uuid4())


class Store:
    def __init__(self, lease, publish=lambda *_: None, clock=lambda: time.time_ns() // 1_000_000):
        self.publish, self.clock = publish, clock
        self.db = None
        self.healthy = True
        self.changes = []
        self.purged = False
        self.media = None
        try:
            # SQLite's companion files have the same trust boundary as the DB.
            for suffix in ("", "-wal", "-shm", "-journal"):
                try:
                    fd = private_file(lease.directory_fd, "history.sqlite3" + suffix, create=not suffix)
                except FileNotFoundError:
                    continue
                os.close(fd)
            self.db = sqlite3.connect(str(lease.data / "history.sqlite3"), isolation_level=None, timeout=.1)
            self.db.row_factory = sqlite3.Row
            schema = self.db.execute("PRAGMA user_version").fetchone()[0]
            if schema > SCHEMA_VERSION:
                raise Failure("unsupported_schema")
            self.db.execute("PRAGMA foreign_keys=ON")
            self.db.execute("PRAGMA trusted_schema=OFF")
            self.db.execute("PRAGMA secure_delete=ON")
            self.db.execute("PRAGMA temp_store=MEMORY")
            if schema == 0:
                if self.db.execute("SELECT 1 FROM sqlite_master WHERE type='table'").fetchone():
                    raise Failure("storage_error")
                with self.transaction():
                    sql = Path(__file__).with_name("signal_schema.sql").read_text()
                    # No executescript: it implicitly commits an open transaction.
                    statement = ""
                    for line in sql.splitlines(keepends=True):
                        statement += line
                        if sqlite3.complete_statement(statement):
                            self.db.execute(statement)
                            statement = ""
            if schema <= 1:
                with self.transaction():
                    statement = ""
                    for line in Path(__file__).with_name("signal_schema_v2.sql").read_text().splitlines(keepends=True):
                        statement += line
                        if sqlite3.complete_statement(statement):
                            self.db.execute(statement)
                            statement = ""
            if schema <= 2:
                with self.transaction():
                    statement = ""
                    for line in Path(__file__).with_name("signal_schema_v3.sql").read_text().splitlines(keepends=True):
                        statement += line
                        if sqlite3.complete_statement(statement):
                            self.db.execute(statement)
                            statement = ""
                    for table in ("receipt_reports", "read_markers"):
                        self.db.execute("DELETE FROM " + table + " WHERE expires_at_ms<=?", (self.clock(),))
            if schema <= 3:
                with self.transaction():
                    statement = ""
                    for line in Path(__file__).with_name("signal_schema_v4.sql").read_text().splitlines(keepends=True):
                        statement += line
                        if sqlite3.complete_statement(statement):
                            self.db.execute(statement)
                            statement = ""
                    self.db.execute("INSERT INTO media_files(attachment_id,filename,state,error_code) SELECT attachment_id,'Załącznik','unavailable','attachment_unavailable' FROM attachments")
                    for row in self.db.execute("SELECT message_id,body,kind FROM messages WHERE fingerprint IS NOT NULL").fetchall():
                        media = [dict(a) for a in self.db.execute("SELECT a.content_type,a.size_bytes FROM attachments a JOIN attachment_refs r USING(attachment_id) WHERE r.message_id=?", (row["message_id"],))]
                        self.db.execute("UPDATE messages SET fingerprint=? WHERE message_id=?", (message_fingerprint(row["body"], row["kind"], media), row["message_id"]))
            if schema <= 4:
                with self.transaction():
                    statement = ""
                    for line in Path(__file__).with_name("signal_schema_v5.sql").read_text().splitlines(keepends=True):
                        statement += line
                        if sqlite3.complete_statement(statement):
                            self.db.execute(statement)
                            statement = ""
            if schema <= 5:
                with self.transaction():
                    statement = ""
                    for line in Path(__file__).with_name("signal_schema_v6.sql").read_text().splitlines(keepends=True):
                        statement += line
                        if sqlite3.complete_statement(statement):
                            self.db.execute(statement)
                            statement = ""
            if schema <= 6:
                with self.transaction():
                    statement = ""
                    for line in Path(__file__).with_name("signal_schema_v7.sql").read_text().splitlines(keepends=True):
                        statement += line
                        if sqlite3.complete_statement(statement):
                            self.db.execute(statement)
                            statement = ""
                    self.db.execute("INSERT OR IGNORE INTO conversation_preferences(conversation_id,initiated) SELECT DISTINCT conversation_id,1 FROM messages WHERE direction='outgoing'")
            if schema <= 4:
                with self.transaction():
                    for row in self.db.execute("SELECT m.message_id,c.account_id FROM messages m JOIN conversations c USING(conversation_id)").fetchall():
                        signal_receipts.apply_message(self, row["account_id"], row["message_id"])
            if self.db.execute("PRAGMA quick_check").fetchone()[0] != "ok":
                raise Failure("storage_error")
            if self.db.execute("PRAGMA journal_mode=WAL").fetchone()[0] != "wal":
                raise Failure("storage_error")
            self.db.execute("PRAGMA synchronous=FULL")
            self.db.execute("PRAGMA wal_autocheckpoint=256")
            self.db.execute("PRAGMA journal_size_limit=0")
            self.purged = True  # Finish a cleanup interrupted after COMMIT.
            with self.transaction():
                # A crash cannot prove whether an inflight operation reached CLI.
                self.db.execute("UPDATE outbox SET state='unknown',error_code='result_unknown',safe_retry=0 WHERE state='sending'")
                self.db.execute("UPDATE outbox_attempts SET state='unknown' WHERE state='sending'")
                self.db.execute("UPDATE messages SET status='unknown' WHERE status='sending'")
                self.db.execute("UPDATE interaction_outbox SET state='unknown',error_code='result_unknown',safe_retry=0 WHERE state='sending'")
                self.db.execute("UPDATE read_queue SET state='unknown' WHERE state='sending'")
                self.db.execute("UPDATE directory_operations SET state='unknown',error_code='result_unknown' WHERE state='sending'")
                self.cleanup()
            self.media = Media(self, lease)
            self.media.gc(startup=True)
            signal_directory.cleanup_avatars(self)
        except BaseException as error:
            if self.db:
                self.db.close()
            self.healthy = False
            if isinstance(error, (sqlite3.Error, OSError)):
                raise Failure("storage_error") from None
            raise

    @contextmanager
    def transaction(self):
        if not self.healthy:
            raise Failure("storage_error")
        self.changes = []
        try:
            self.db.execute("BEGIN IMMEDIATE")
            yield
            self.db.execute("COMMIT")
            if self.media:
                self.media.gc()
            if self.purged:
                # Old body pages in WAL are part of retention. A busy reader or
                # failed checkpoint blocks publication and requires recovery.
                if self.db.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()[0]:
                    raise sqlite3.OperationalError("checkpoint busy")
                self.purged = False
        except BaseException as error:
            if self.db.in_transaction:
                self.db.execute("ROLLBACK")
            self.changes = []
            if isinstance(error, (sqlite3.Error, OSError)):
                self.healthy = False
                raise Failure("storage_error") from None
            raise
        changes, self.changes = self.changes, []
        for name, data in changes:
            self.publish(name, data)

    def close(self):
        try:
            if self.healthy:
                self.db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        finally:
            self.db.close()

    def changed(self, name, **data):
        value = (name, data)
        if value not in self.changes:
            self.changes.append(value)

    def bind_account(self, sid, cli_address):
        sid = service_id(sid)
        if not sid.startswith("aci:"):
            raise Failure("account_identity_unknown")
        cli_address = text(cli_address, 128, empty=False)
        with self.transaction():
            row = self.db.execute("SELECT * FROM accounts WHERE service_id=?", (sid,)).fetchone()
            account = row["account_id"] if row else new_id()
            self.db.execute("INSERT INTO accounts VALUES(?,?,?) ON CONFLICT(service_id) DO UPDATE SET cli_address=excluded.cli_address",
                            (account, sid, cli_address))
            self.db.execute("INSERT INTO store_metadata VALUES('active_account',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", (account,))
        return account

    def active_account(self):
        row = self.db.execute("SELECT value FROM store_metadata WHERE key='active_account'").fetchone()
        return row[0] if row else ""

    def account(self, account):
        row = self.db.execute("SELECT * FROM accounts WHERE account_id=?", (identifier(account),)).fetchone()
        if not row:
            raise Failure("account_unlinked")
        return row

    def recipient(self, account, sid, number=None):
        if not sid:
            # A number-only record stays unresolved, never merged by display name.
            sid = "unresolved:" + text(number, 128, empty=False)
        row = self.db.execute("SELECT * FROM recipients WHERE account_id=? AND service_id=?", (account, sid)).fetchone()
        rid = row["recipient_id"] if row else new_id()
        self.db.execute("INSERT OR IGNORE INTO recipients VALUES(?,?,?,?)", (rid, account, sid, not sid.startswith("unresolved:")))
        if number:
            self.db.execute("INSERT OR IGNORE INTO recipient_aliases VALUES(?,?)", (rid, number))
        return rid, sid if not sid.startswith("unresolved:") else "unresolved:" + rid

    def route(self, account, route):
        own = self.account(account)["service_id"]
        if route.get("group"):
            kind, target, peer = "group", group_id(route["group"]), None
        else:
            peer, target = self.recipient(account, route.get("peer"), route.get("number"))
            kind = "note" if target == own else "direct"
        row = self.db.execute("SELECT * FROM conversations WHERE account_id=? AND kind=? AND target=?", (account, kind, target)).fetchone()
        if row:
            return row["conversation_id"]
        cid = new_id()
        self.db.execute("INSERT INTO conversations(conversation_id,account_id,kind,peer_id,target,title) VALUES(?,?,?,?,?,?)",
                        (cid, account, kind, peer, target, route.get("title", "")))
        self.changed("conversation.changed", accountId=account, conversationId=cid)
        return cid

    def conversation(self, account, cid):
        row = self.db.execute("SELECT * FROM conversations WHERE account_id=? AND conversation_id=?", (account, identifier(cid))).fetchone()
        if not row:
            raise Failure("not_found")
        return row

    def open_conversation(self, account, params):
        self.account(account)
        kind = params.get("kind", "direct")
        route = {"peer": service_id(params.get("serviceId"))} if kind == "direct" else (
            {"group": group_id(params.get("groupId"))} if kind == "group" else
            {"peer": self.account(account)["service_id"]} if kind == "note" else None)
        if route is None:
            raise Failure("invalid_request")
        with self.transaction():
            existed = self.db.execute("SELECT 1 FROM conversations WHERE account_id=? AND target=?", (account, route.get('peer') or route.get('group'))).fetchone()
            cid = self.route(account, route)
            if not existed and kind != 'group':
                self.db.execute('INSERT INTO conversation_preferences(conversation_id,initiated) VALUES(?,1)', (cid,))
        return {"conversationId": cid}

    def directory(self, account):
        row = self.db.execute("SELECT value FROM store_metadata WHERE key=?", ("directory:" + account,)).fetchone()
        return json.loads(row[0]) if row else {"contacts": [], "groups": []}

    def conversation_item(self, account, cid, directory=None):
        row = self.conversation(account, cid)
        directory = directory if directory is not None else self.directory(account)
        contact = next((v for v in directory["contacts"] if v["serviceId"] == row["target"]), {})
        group = next((v for v in directory["groups"] if v["groupId"] == row["target"]), {})
        title = group.get("name") if row["kind"] == "group" else contact.get("name") or contact.get("profileName") or contact.get("number")
        unread = self.db.execute("SELECT COUNT(*) FROM messages WHERE conversation_id=? AND direction='incoming' AND read_at_ms IS NULL AND kind NOT IN ('deleted','expired')", (cid,)).fetchone()[0]
        return {"conversationId": cid, "kind": row["kind"], "target": row["target"],
                "title": title or row["title"] or ("Notatka" if row["kind"] == "note" else row["target"]),
                "searchText": " ".join(str(contact.get(k) or "") for k in ("name", "profileName", "number")),
                "activityTimestampMs": row["activity_ms"], "expirationSeconds": row["expiration_seconds"],
                "muted": signal_replies.muted(self, cid),
                "unreadCount": unread, **signal_directory.access(self, account, row, contact, group)}

    def touch(self, account, cid, timestamp):
        self.db.execute("UPDATE conversations SET activity_ms=MAX(activity_ms,?) WHERE conversation_id=?", (timestamp, cid))
        self.changed("conversation.changed", accountId=account, conversationId=cid)

    def notify_message(self, account, mid):
        row = self.db.execute("SELECT conversation_id FROM messages WHERE message_id=?", (mid,)).fetchone()
        self.changed("message.changed", accountId=account, conversationId=row[0], messageId=mid)

    def redact(self, account, cid, author, timestamp, reason):
        stamps = signal_retention.aliases(self, cid, author, timestamp, reason)
        for stamp in stamps:
            row = signal_interactions.target(self, cid, author, stamp)
            if row:
                self.redact_message(account, row["message_id"], reason)
        signal_retention.purge_copies(self, account, cid, author, stamps)

    def redact_message(self, account, mid, reason):
        self.purged = True
        row = self.db.execute("SELECT * FROM messages WHERE message_id=?", (mid,)).fetchone()
        if row["sent_ms"] is not None:
            stamps = signal_retention.aliases(self, row["conversation_id"], row["author"], row["sent_ms"], reason)
            signal_retention.purge_copies(self, account, row["conversation_id"], row["author"], stamps)
        signal_interactions.purge(self, mid)
        self.db.execute("UPDATE messages SET body=NULL,fingerprint=NULL,kind=?,expires_at_ms=NULL WHERE message_id=?", (reason, mid))
        aids = [r[0] for r in self.db.execute("SELECT attachment_id FROM attachment_refs WHERE message_id=?", (mid,))]
        self.db.execute("DELETE FROM attachment_refs WHERE message_id=?", (mid,))
        if self.media:
            self.media.retire(aids)
        self.db.execute("DELETE FROM attachments WHERE NOT EXISTS(SELECT 1 FROM attachment_refs r WHERE r.attachment_id=attachments.attachment_id) AND NOT EXISTS(SELECT 1 FROM draft_attachments d WHERE d.attachment_id=attachments.attachment_id)")
        # Outbox references this one content owner, never a second payload copy.
        self.db.execute("UPDATE outbox SET safe_retry=0 WHERE message_id=?", (mid,))
        self.db.execute("UPDATE outbox SET state='failed',safe_retry=0,error_code=? WHERE message_id=? AND state='queued'", (reason, mid))
        for operation in self.db.execute("SELECT operation_id,conversation_id FROM outbox WHERE message_id=?", (mid,)):
            self.changed("operation.changed", accountId=account, conversationId=operation["conversation_id"],
                         operationId=operation["operation_id"], messageId=mid)
        self.notify_message(account, mid)
        self.changed("message.redacted", accountId=account, conversationId=row["conversation_id"], messageId=mid)
        self.changed("conversation.changed", accountId=account, conversationId=row["conversation_id"])

    def cleanup(self):
        now = integer(self.clock())
        for table in ("message_versions", "message_reactions"):
            if self.db.execute("DELETE FROM " + table + " WHERE expires_at_ms<=?", (now,)).rowcount:
                self.purged = True
        if self.db.execute("UPDATE interaction_outbox SET payload='{}',safe_retry=0,state=CASE WHEN state='queued' THEN 'cancelled' ELSE state END WHERE expires_at_ms<=? AND payload!='{}'", (now,)).rowcount:
            self.purged = True
        self.db.execute("DELETE FROM pending_events WHERE expires_at_ms<=?", (now,))
        self.db.execute("DELETE FROM receipt_reports WHERE expires_at_ms<=?", (now,))
        self.db.execute("DELETE FROM read_markers WHERE expires_at_ms<=?", (now,))
        rows = self.db.execute("SELECT m.*,c.account_id FROM messages m JOIN conversations c USING(conversation_id) WHERE expires_at_ms<=?", (now,)).fetchall()
        for row in rows:
            if row["sent_ms"] is not None:
                self.redact(row["account_id"], row["conversation_id"], row["author"], row["sent_ms"], "expired")
            else:
                self.redact_message(row["account_id"], row["message_id"], "expired")

    def pending(self, account, event, cid=None):
        # These are hooks for S06/S08. Only identifiers/type/times, never body,
        # quotes, emoji, raw result/error data, filenames or attachment payloads.
        key = digest([account, cid, event["kind"], event["author"], event.get("actor"), event["target_ms"], event["event_ms"]])
        self.db.execute("INSERT OR IGNORE INTO pending_events VALUES(?,?,?,?,?,?,?,?)",
                        (key, account, cid, event["kind"], event["author"], event["target_ms"], event["event_ms"], self.clock() + PENDING_TTL))
        if self.db.execute("SELECT COUNT(*) FROM pending_events").fetchone()[0] > 10000:
            raise Failure("overloaded")

    def receive(self, account, wire):
        own = self.account(account)
        if wire.get("method") == "receive" and wire.get("params", {}).get("result", {}).get("account") != own["cli_address"]:
            from signal_events import EventFailure
            raise EventFailure("account_binding")
        events = normalize(wire, own["service_id"])
        with self.transaction():
            self.cleanup()
            for event in events:
                if event["kind"] == "typing":
                    continue  # Bridge owns ephemeral timers; no history or route creation.
                if "route" not in event:
                    signal_receipts.receive(self, account, event)
                    continue
                cid = self.route(account, event["route"])
                if not event["author"]:
                    _, event["author"] = self.recipient(account, None, event["author_number"])
                else:
                    identity = event.get("actor") if event["kind"] == "reaction" else event["author"]
                    if identity and identity != own["service_id"]:
                        self.recipient(account, identity, event.get("author_number"))
                kind = event["kind"]
                if kind == "delete":
                    self.redact(account, cid, event["author"], event["target_ms"], "deleted")
                elif kind in ("edit", "reaction"):
                    signal_interactions.receive(self, account, cid, event)
                else:
                    if kind == "expiration_update" or event.get("expiration_seconds", 0):
                        signal_retention.configure(self, account, cid, event["expiration_seconds"], event["event_ms"])
                    if kind == "message":
                        self.insert_message(account, cid, event)

    def insert_message(self, account, cid, event):
        key = (cid, event["author"], event["event_ms"])
        deleted = self.db.execute("SELECT reason FROM tombstones WHERE conversation_id=? AND author=? AND sent_ms=?", key).fetchone()
        edit = self.db.execute("SELECT 1 FROM pending_events WHERE conversation_id=? AND author=? AND target_ms=? AND kind='edit'", key).fetchone()
        kind = deleted[0] if deleted else "edit_unsupported" if edit else event["message_kind"]
        hidden = deleted or edit or kind.endswith("_unsupported")
        body, attachments = (None, []) if hidden else (event["body"], event["attachments"])
        fingerprint = None if hidden else message_fingerprint(body, kind, attachments)
        row = self.db.execute("SELECT * FROM messages WHERE conversation_id=? AND author=? AND sent_ms=?", key).fetchone()
        if row or hidden:
            # Duplicate/sent-sync/tombstoned payloads may still have caused CLI
            # to download a fresh copy. Persist its cleanup before dropping IDs.
            self.db.executemany("INSERT OR IGNORE INTO media_cli_gc VALUES(?)", [(a["cli_id"],) for a in event["attachments"]])
        if row:
            mid = row["message_id"]
            if hidden and row["kind"] not in ("deleted", "expired"):
                self.redact_message(account, mid, kind)
            elif fingerprint and row["fingerprint"] and fingerprint != row["fingerprint"]:
                self.db.execute("UPDATE messages SET conflict=1 WHERE message_id=?", (mid,))
                self.notify_message(account, mid)
            if event.get("expiration_start_ms"):
                signal_retention.start(self, account, mid, event["expiration_start_ms"])
            return mid
        mid = new_id()
        self.db.execute("""INSERT INTO messages(message_id,conversation_id,author,sent_ms,sort_ms,source_device,
            server_received_ms,direction,origin,kind,body,fingerprint,status) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                        (mid, *key, event["event_ms"], event["source_device"], event["server_received_ms"],
                         event["direction"], event["origin"], kind, body, fingerprint,
                         "sent" if event["direction"] == "outgoing" else "received"))
        self.db.execute("UPDATE messages SET expiration_seconds=? WHERE message_id=?", (event.get("expiration_seconds", 0), mid))
        for item in attachments:
            aid = new_id()
            self.db.execute("INSERT OR IGNORE INTO attachments VALUES(?,?,?,?,?)",
                            (aid, account, item["cli_id"], item["content_type"], item["size_bytes"]))
            aid = self.db.execute("SELECT attachment_id FROM attachments WHERE account_id=? AND cli_id=?", (account, item["cli_id"])).fetchone()[0]
            self.db.execute("INSERT OR IGNORE INTO media_files(attachment_id,filename,voice_note) VALUES(?,?,?)", (aid, filename(item.get("filename")), item.get("voice_note", False)))
            self.db.execute("INSERT INTO attachment_refs VALUES(?,?)", (mid, aid))
        signal_interactions.base(self, mid, {} if hidden else signal_retention.clean_metadata(self, cid, event.get("metadata", {})))
        signal_interactions.resolve(self, account, cid)
        signal_interactions.refresh_quotes(self, account, cid, event["author"], event["event_ms"])
        self.touch(account, cid, event["event_ms"])
        signal_receipts.apply_message(self, account, mid)
        self.notify_message(account, mid)
        if event.get("expiration_start_ms"):
            signal_retention.start(self, account, mid, event["expiration_start_ms"])
        current = self.db.execute("SELECT read_at_ms,kind FROM messages WHERE message_id=?", (mid,)).fetchone()
        read, kind = current["read_at_ms"], current["kind"]
        if event["direction"] == "incoming" and event["origin"] == "remote" and read is None and kind not in ("deleted", "expired", "edit_unsupported"):
            self.changed("message.received", accountId=account, conversationId=cid, messageId=mid)

    def draft(self, account, cid):
        self.conversation(account, cid)
        row = self.db.execute("SELECT body,revision,composition FROM drafts WHERE conversation_id=?", (cid,)).fetchone()
        result = {"conversationId": cid, "text": row[0] if row else "", "revision": row[1] if row else 0}
        if row and row["composition"] != "{}":
            result["composition"] = json.loads(row["composition"])
        if self.media:
            result["attachments"] = self.media.draft(account, cid)
        return result

    def set_draft(self, account, params):
        cid, body, revision = params.get("conversationId"), text(params.get("text")), integer(params.get("expectedRevision"))
        self.conversation(account, cid)
        from signal_content import ranges
        composition = params.get("composition", {})
        if not isinstance(composition, dict):
            raise Failure("invalid_request")
        clean = {}
        if composition.get("mentions"):
            clean["mentions"] = ranges(body, composition["mentions"], mentions=True)
        if composition.get("quoteMessageId"):
            quote = self.message(account, composition["quoteMessageId"])
            if quote["conversationId"] != cid or quote["kind"] not in ("text", "media"):
                raise Failure("invalid_request")
            clean["quoteMessageId"] = quote["messageId"]
        with self.transaction():
            current = self.draft(account, cid)
            if current["revision"] != revision:
                raise Failure("draft_conflict")
            self.db.execute("INSERT INTO drafts(conversation_id,body,revision,composition) VALUES(?,?,?,?) ON CONFLICT(conversation_id) DO UPDATE SET body=excluded.body,revision=excluded.revision,composition=excluded.composition",
                            (cid, body, revision + 1, signal_interactions.encoded(clean)))
            self.changed("draft.changed", accountId=account, conversationId=cid, revision=revision + 1)
        return self.draft(account, cid)

    def message(self, account, mid):
        row = self.db.execute("SELECT m.* FROM messages m JOIN conversations c USING(conversation_id) WHERE c.account_id=? AND message_id=?",
                              (account, identifier(mid))).fetchone()
        if not row:
            raise Failure("not_found")
        media = [self.media.item(account, r[0]) for r in self.db.execute("SELECT attachment_id FROM attachment_refs WHERE message_id=?", (mid,))] if self.media else []
        operation = self.db.execute("SELECT operation_id,safe_retry FROM outbox WHERE message_id=?", (mid,)).fetchone()
        metadata = self.db.execute("SELECT payload FROM message_metadata WHERE message_id=?", (mid,)).fetchone()
        return {"systemChanges": json.loads(metadata[0]).get("systemChanges", []) if metadata else [], "messageId": mid, "conversationId": row["conversation_id"], "authorServiceId": row["author"],
                "sentTimestampMs": row["sent_ms"], "sortTimestampMs": row["sort_ms"], "direction": row["direction"],
                "origin": row["origin"], "kind": row["kind"], "text": row["body"], **signal_receipts.summary(self, account, row),
                "operationId": operation[0] if operation else "", "safeRetry": bool(operation and operation[1]),
                "readAtMs": row["read_at_ms"], "unread": row["direction"] == "incoming" and row["read_at_ms"] is None and row["kind"] not in ("deleted", "expired"),
                "hiddenLocal": bool(row["hidden_local"]), "expirationSeconds": row["expiration_seconds"], "expirationStartMs": row["expiration_start_ms"],
                "canDeleteLocal": not row["hidden_local"], "canDeleteRemote": signal_retention.can_remote_delete(self, account, row),
                "conflict": bool(row["conflict"]), "expiresAtMs": row["expires_at_ms"], "attachments": media,
                **signal_interactions.summary(self, account, row)}

    def page(self, account, params, *, messages=False):
        self.account(account)
        limit = integer(params.get("limit", 50), minimum=1)
        if limit > 100:
            raise Failure("invalid_request")
        cid = params.get("conversationId") if messages else None
        if messages:
            self.conversation(account, cid)
        scope = [account, "messages" if messages else "conversations", cid]
        cursor = params.get("before")
        position = None
        if cursor is not None:
            try:
                decoded = json.loads(base64.b64decode(text(cursor, 1024), validate=True))
                if not isinstance(decoded, list) or len(decoded) != 5 or decoded[:3] != scope:
                    raise ValueError()
                position = (integer(decoded[3]), identifier(decoded[4]))
            except (ValueError, TypeError, Failure):
                raise Failure("invalid_cursor") from None
        table, sort, pk, field, value = ("messages", "sort_ms", "message_id", "conversation_id", cid) if messages else (
            "conversations", "activity_ms", "conversation_id", "account_id", account)
        # Table/column names are exclusively the constants above, never IPC input.
        sql = f"SELECT * FROM {table} WHERE {field}=?"
        if messages:
            sql += " AND hidden_local=0"
        bindings = [value]
        if position:
            sql += f" AND ({sort},{pk}) < (?,?)"
            bindings.extend(position)
        rows = self.db.execute(sql + f" ORDER BY {sort} DESC,{pk} DESC LIMIT ?", [*bindings, limit + 1]).fetchall()
        items, size, last = [], 0, None
        directory = self.directory(account) if not messages else None
        for row in rows[:limit]:
            item = self.message(account, row[pk]) if messages else self.conversation_item(account, row[pk], directory)
            encoded = json.dumps(item, ensure_ascii=False).encode()
            if size + len(encoded) > PAGE_BYTES and items:
                break
            items.append(item)
            size += len(encoded)
            last = [row[sort], row[pk]]
        next_cursor = base64.b64encode(json.dumps(scope + last).encode()).decode() if last and len(rows) > len(items) else None
        return {"items": items, "nextCursor": next_cursor}
