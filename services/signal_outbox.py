"""One durable queue for all callers. A local UUID is not server idempotency."""
from signal_events import digest, identifier, integer, message_fingerprint, service_id, text
from signal_store import OUTBOX_TTL, new_id
from signal_transport import Failure
import signal_replies
import signal_receipts
import signal_interactions
import signal_retention
from signal_content import send_fields
from signal_mutations import Mutations

DEFINITE_FAILURES = {"UNREGISTERED_FAILURE", "IDENTITY_FAILURE", "RATE_LIMIT_FAILURE", "INVALID_PRE_KEY_FAILURE"}


class Outbox:
    def __init__(self, store, require_timer=False):
        self.require_timer = require_timer
        self.store = store
        self.db = store.db
        self.mutations = Mutations(self)

    def row(self, account, operation):
        row = self.db.execute("SELECT * FROM outbox WHERE account_id=? AND operation_id=?", (account, identifier(operation))).fetchone()
        if not row:
            row = self.mutations.row(account, operation)
        if not row:
            raise Failure("not_found")
        return row

    def status(self, account, operation):
        row = self.row(account, operation)
        if "kind" in row.keys():
            return self.mutations.status(row)
        results = [dict(r) for r in self.db.execute(
            "SELECT recipient,result_type,retry_after_seconds FROM outbox_results WHERE operation_id=? AND attempt=? ORDER BY recipient",
            (operation, row["attempt"]))]
        return {"operationId": operation, "conversationId": row["conversation_id"], "messageId": row["message_id"],
                "state": row["state"], "errorCode": row["error_code"], "safeRetry": bool(row["safe_retry"]),
                "attempt": row["attempt"], "recipients": results}

    def changed(self, row):
        self.store.changed("operation.changed", accountId=row["account_id"], operationId=row["operation_id"],
                           conversationId=row["conversation_id"], messageId=row["message_id"])
        self.store.notify_message(row["account_id"], row["message_id"])

    def enqueue(self, account, params):
        cid = params.get("conversationId")
        body = text(params.get("text", ""))
        aids = params.get("attachmentIds", [])
        if not isinstance(aids, list) or len(aids) > 8 or len(set(aids)) != len(aids):
            raise Failure("invalid_request")
        aids = [identifier(aid) for aid in aids]
        if not body.strip() and not aids:
            raise Failure("invalid_request")
        op = identifier(params["operationId"]) if "operationId" in params else new_id()
        conversation = self.store.conversation(account, cid)
        own = self.store.account(account)["service_id"]
        metadata = signal_interactions.compose_metadata(self.store, account, cid, params, body)
        with self.store.transaction():
            self.store.cleanup()
            existing = self.db.execute("SELECT o.*,m.body FROM outbox o JOIN messages m USING(message_id) WHERE operation_id=?", (op,)).fetchone()
            if self.mutations.row(account, op):
                raise Failure("operation_conflict")
            if existing:
                saved = [r[0] for r in self.db.execute("SELECT attachment_id FROM attachment_refs WHERE message_id=? ORDER BY attachment_id", (existing["message_id"],))]
                if existing["account_id"] != account or existing["conversation_id"] != cid or existing["body"] != body or sorted(aids) != saved or signal_interactions.current_meta(self.store, existing["message_id"]) != metadata:
                    raise Failure("operation_conflict")
                return self.status(account, op)
            if conversation["target"].startswith(("unresolved:", "pni:")):
                raise Failure("recipient_unresolved")
            if self.db.execute("SELECT COUNT(*) FROM outbox WHERE state='queued'").fetchone()[0] >= 1000:
                raise Failure("overloaded")
            context = params.get("draftContext", "composer")
            if context not in ("composer", "quickReply"):
                raise Failure("invalid_request")
            if context == "quickReply" and aids:
                raise Failure("invalid_request")
            staged = self.store.media.draft(account, cid)
            if aids and sorted(aids) != sorted(a["attachment_id"] for a in staged):
                raise Failure("draft_conflict")
            if any(a["state"] != "ready" for a in staged if a["attachment_id"] in aids):
                raise Failure("attachment_unavailable")
            if "draftRevision" in params and context == "composer":
                draft = self.store.draft(account, cid)
                if draft["revision"] != integer(params["draftRevision"]) or draft["text"] != body:
                    raise Failure("draft_conflict")
                self.db.execute("UPDATE drafts SET body='',composition='{}',revision=revision+1 WHERE conversation_id=?", (cid,))
                self.store.changed("draft.changed", accountId=account, conversationId=cid, revision=draft["revision"] + 1)
            mid, now = new_id(), integer(self.store.clock())
            self.db.execute("""INSERT INTO messages(message_id,conversation_id,author,sort_ms,direction,origin,kind,body,fingerprint,status,expires_at_ms)
                VALUES(?,?,?,?,'outgoing','local',?,?,?,'queued',?)""", (mid, cid, own, now, "media" if aids else "text", body,
                    message_fingerprint(body, "media" if aids else "text", [a for a in staged if a["attachment_id"] in aids]), now + OUTBOX_TTL))
            signal_interactions.set_meta(self.store, mid, metadata)
            for aid in aids:
                self.db.execute("INSERT INTO attachment_refs VALUES(?,?)", (mid, aid))
                self.db.execute("DELETE FROM draft_attachments WHERE conversation_id=? AND attachment_id=?", (cid, aid))
            if aids:
                self.store.changed("attachments.changed", accountId=account, conversationId=cid)
            self.db.execute("INSERT INTO outbox(operation_id,account_id,conversation_id,message_id,state,created_ms) VALUES(?,?,?,?,'queued',?)",
                            (op, account, cid, mid, now))
            if context == "quickReply":
                signal_replies.attach(self.store, account, params, op)
            self.store.touch(account, cid, now)
            self.changed(self.row(account, op))
        return self.status(account, op)

    def next(self, account):
        row = self.db.execute("SELECT operation_id FROM (SELECT operation_id,created_ms FROM outbox WHERE account_id=? AND state='queued' UNION ALL SELECT operation_id,created_ms FROM interaction_outbox WHERE account_id=? AND state='queued') ORDER BY created_ms,operation_id LIMIT 1", (account, account)).fetchone()
        return row[0] if row else None

    def rpc_method(self, account, operation):
        row = self.mutations.row(account, operation)
        return {"reaction": "sendReaction", "delete": "remoteDelete"}.get(row["kind"], "send") if row else "send"

    def begin(self, account, operation):
        mutation = self.mutations.row(account, operation)
        if mutation:
            return self.mutations.begin(mutation)
        with self.store.transaction():
            self.store.cleanup()
            row = self.row(account, operation)
            if row["state"] != "queued":
                raise Failure("operation_not_queued")
            message = self.store.message(account, row["message_id"])
            if message["kind"] not in ("text", "media") or message["text"] is None:
                raise Failure("retention_unsupported")
            conversation = self.store.conversation(account, row["conversation_id"])
            attempt = row["attempt"] + 1
            self.db.execute("UPDATE outbox SET state='sending',attempt=?,error_code='',safe_retry=0 WHERE operation_id=?", (attempt, operation))
            self.db.execute("INSERT INTO outbox_attempts VALUES(?,?,'sending',NULL,?)", (operation, attempt, self.store.clock()))
            self.db.execute("UPDATE messages SET status='sending',expiration_seconds=? WHERE message_id=?", (conversation["expiration_seconds"], row["message_id"]))
            self.changed(row)
            params = {"account": self.store.account(account)["cli_address"], "message": message["text"],
                      **send_fields(signal_interactions.current_meta(self.store, row["message_id"]))}
            if message["kind"] == "media":
                params["attachment"] = self.store.media.send_paths(account, row["message_id"])
                if not params["attachment"]:
                    raise Failure("attachment_unavailable")
            if conversation["kind"] == "group":
                params["groupId"] = [conversation["target"]]
            elif conversation["kind"] == "note":
                params["noteToSelf"] = True
            else:
                params["recipient"] = [conversation["target"].removeprefix("aci:")]
        return params, attempt

    def fail(self, account, operation, code, *, definite=False):
        mutation = self.mutations.row(account, operation)
        if mutation:
            return self.mutations.fail(mutation, code, definite)
        with self.store.transaction():
            row = self.row(account, operation)
            if row["state"] in ("sent", "cancelled"):
                return
            state = "failed" if definite else "unknown"
            self.db.execute("UPDATE outbox SET state=?,error_code=?,safe_retry=? WHERE operation_id=?", (state, code, definite, operation))
            self.db.execute("UPDATE messages SET status=? WHERE message_id=?", (state, row["message_id"]))
            self.db.execute("UPDATE outbox_attempts SET state=? WHERE operation_id=? AND attempt=?", (state, operation, row["attempt"]))
            if self.store.message(account, row["message_id"])["kind"] in ("deleted", "expired"):
                self.db.execute("UPDATE outbox SET safe_retry=0 WHERE operation_id=?", (operation,))
            if code == "retention_unsupported":
                self.store.redact_message(account, row["message_id"], "expiring_unsupported")
                self.db.execute("UPDATE outbox SET safe_retry=0 WHERE operation_id=?", (operation,))
            self.changed(row)

    def finish(self, account, operation, attempt, result, error=None):
        mutation = self.mutations.row(account, operation)
        if mutation:
            return self.mutations.finish(mutation, attempt, result, error)
        row = self.row(account, operation)
        if row["attempt"] != attempt or row["state"] not in ("sending", "unknown"):
            return  # A response from an old attempt cannot settle its successor.
        if error is not None:
            # JSON-RPC errors may follow partial effects. Never retain their data.
            self.fail(account, operation, "result_unknown")
            return
        try:
            timestamp = integer(result["timestamp"], minimum=1)
            timer = integer(result["expiresInSeconds"]) if "expiresInSeconds" in result else None
            if self.require_timer and timer is None:
                raise ValueError()
            results = result["results"]
            if not isinstance(results, list) or not results or len(results) > 1000:
                raise ValueError()
            clean = []
            for entry in results:
                address = entry["recipientAddress"]
                recipient = service_id(address["uuid"]) if address.get("uuid") else "unresolved:" + text(address["number"], 128, empty=False)
                kind = text(entry["type"], 64, empty=False)
                retry = integer(entry["retryAfterSeconds"]) if "retryAfterSeconds" in entry else None
                clean.append((recipient, kind, retry))
            if len({r[0] for r in clean}) != len(clean):
                raise ValueError()
            conversation = self.store.conversation(account, row["conversation_id"])
            if conversation["kind"] != "group" and (len(clean) != 1 or clean[0][0] != conversation["target"]):
                raise ValueError()
        except (KeyError, TypeError, ValueError, Failure):
            self.fail(account, operation, "invalid_send_result")
            return
        success = all(r[1] == "SUCCESS" for r in clean)
        definite = all(r[1] in DEFINITE_FAILURES for r in clean)
        partial = any(r[1] == "SUCCESS" for r in clean)
        uncertain = any(r[1] not in DEFINITE_FAILURES | {"SUCCESS"} for r in clean)
        state = "sent" if success else "unknown" if uncertain else "failed"
        with self.store.transaction():
            self.db.execute("UPDATE outbox SET state=?,error_code=?,safe_retry=? WHERE operation_id=?",
                            (state, "" if success else "partial_send" if partial else "send_failed", definite, operation))
            self.db.execute("UPDATE outbox_attempts SET state=?,sent_ms=? WHERE operation_id=? AND attempt=?", (state, timestamp, operation, attempt))
            self.db.executemany("INSERT INTO outbox_results VALUES(?,?,?,?,?)", [(operation, attempt, *r) for r in clean])
            self.db.execute("DELETE FROM message_recipients WHERE message_id=?", (row["message_id"],))
            self.db.executemany("INSERT INTO message_recipients VALUES(?,?)", [(row["message_id"], r[0]) for r in clean])
            if timer is not None:
                self.db.execute("UPDATE messages SET expiration_seconds=? WHERE message_id=? AND expiration_start_ms IS NULL", (timer, row["message_id"]))
            if not definite:
                self.reconcile(row, timestamp, state)
            else:
                self.db.execute("UPDATE messages SET status=? WHERE message_id=?", (state, row["message_id"]))
            self.changed(row)

    def reconcile(self, operation, timestamp, state):
        account, cid, mid = operation["account_id"], operation["conversation_id"], operation["message_id"]
        local = self.db.execute("SELECT * FROM messages WHERE message_id=?", (mid,)).fetchone()
        copy = self.db.execute("SELECT * FROM messages WHERE conversation_id=? AND author=? AND sent_ms=? AND message_id!=?",
                               (cid, local["author"], timestamp, mid)).fetchone()
        if copy:
            # Exact protocol key, never text/time proximity. Preserve the local
            # optimistic ID; tell keyed models which synced ID was absorbed.
            if self.db.execute("SELECT 1 FROM outbox WHERE message_id=?", (copy["message_id"],)).fetchone():
                self.db.execute("UPDATE messages SET conflict=1 WHERE message_id=?", (mid,))
                self.db.execute("UPDATE outbox SET state='unknown',error_code='identity_conflict',safe_retry=0 WHERE operation_id=?", (operation["operation_id"],))
                self.db.execute("UPDATE messages SET status='unknown' WHERE message_id=?", (mid,))
                return
            if copy["kind"] in ("deleted", "expired") or copy["kind"].endswith("_unsupported"):
                self.store.redact_message(account, mid, copy["kind"])
            elif copy["fingerprint"] != local["fingerprint"]:
                self.db.execute("UPDATE messages SET conflict=1 WHERE message_id=?", (mid,))
            self.db.execute("UPDATE message_versions SET message_id=? WHERE message_id=?", (mid, copy["message_id"]))
            self.db.execute("UPDATE message_reactions SET message_id=? WHERE message_id=?", (mid, copy["message_id"]))
            self.db.execute("UPDATE interaction_outbox SET message_id=? WHERE message_id=?", (mid, copy["message_id"]))
            self.db.execute("INSERT OR IGNORE INTO version_recipients SELECT ?,version_ms,recipient FROM version_recipients WHERE message_id=?", (mid, copy["message_id"]))
            if copy["edited_ms"] and local["kind"] not in ("deleted", "expired"):
                self.db.execute("UPDATE messages SET edited_ms=?,body=? WHERE message_id=?", (copy["edited_ms"], copy["body"], mid))
                signal_interactions.set_meta(self.store, mid, signal_interactions.current_meta(self.store, copy["message_id"]))
            if copy["expiration_start_ms"]:
                self.db.execute("UPDATE messages SET expiration_seconds=?,expiration_start_ms=?,expires_at_ms=? WHERE message_id=?", (copy["expiration_seconds"], copy["expiration_start_ms"], copy["expires_at_ms"], mid))
            self.db.execute("DELETE FROM messages WHERE message_id=?", (copy["message_id"],))
            self.store.changed("message.removed", accountId=account, conversationId=cid, messageId=copy["message_id"], replacementId=mid)
        self.db.execute("UPDATE messages SET sent_ms=?,sort_ms=?,status=?,expires_at_ms=CASE WHEN ?='sent' AND expiration_start_ms IS NULL THEN NULL ELSE expires_at_ms END WHERE message_id=?",
                        (timestamp, timestamp, state, state, mid))
        tombstone = self.db.execute("SELECT reason FROM tombstones WHERE conversation_id=? AND author=? AND sent_ms=?", (cid, local["author"], timestamp)).fetchone()
        if tombstone:
            self.store.redact_message(account, mid, tombstone[0])
        signal_interactions.base(self.store, mid)
        signal_interactions.resolve(self.store, account, cid)
        self.store.touch(account, cid, timestamp)
        signal_receipts.apply_message(self.store, account, mid)
        signal_retention.start(self.store, account, mid, timestamp)
        if local["kind"] in ("deleted", "expired"):
            self.store.redact(account, cid, local["author"], timestamp, local["kind"])

    def cancel(self, account, operation):
        mutation = self.mutations.row(account, operation)
        if mutation:
            return self.mutations.change(mutation, False)
        with self.store.transaction():
            row = self.row(account, operation)
            if row["state"] != "queued":
                raise Failure("operation_not_queued")
            self.db.execute("UPDATE outbox SET state='cancelled',safe_retry=0 WHERE operation_id=?", (operation,))
            self.db.execute("UPDATE messages SET status='cancelled' WHERE message_id=?", (row["message_id"],))
            self.db.execute("DELETE FROM attachment_refs WHERE message_id=?", (row["message_id"],))
            self.changed(row)
        return self.status(account, operation)

    def retry(self, account, operation):
        mutation = self.mutations.row(account, operation)
        if mutation:
            return self.mutations.change(mutation, True)
        with self.store.transaction():
            self.store.cleanup()
            row = self.row(account, operation)
            if row["state"] != "failed" or not row["safe_retry"]:
                raise Failure("retry_unsafe")
            message = self.store.message(account, row["message_id"])
            if message["kind"] not in ("text", "media") or message["text"] is None:
                raise Failure("retention_unsupported")
            wait = self.db.execute("""SELECT MAX(a.started_ms+r.retry_after_seconds*1000) FROM outbox_attempts a
                JOIN outbox_results r USING(operation_id,attempt) WHERE a.operation_id=? AND a.attempt=?""", (operation, row["attempt"])).fetchone()[0]
            if wait and wait > self.store.clock():
                raise Failure("retry_not_ready")
            self.db.execute("UPDATE outbox SET state='queued',safe_retry=0,error_code='' WHERE operation_id=?", (operation,))
            self.db.execute("UPDATE messages SET status='queued' WHERE message_id=?", (row["message_id"],))
            self.changed(row)
        return self.status(account, operation)
