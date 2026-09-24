"""Receipt reducer and durable, conversation-scoped local reads."""
from signal_events import identifier, integer, service_id
from signal_transport import Failure
import signal_retention

TTL = 7 * 86400000
RANK = {"delivery": 1, "read": 2, "viewed": 3}


def recipients(store, message):
    stamp = message["edited_ms"] or message["sent_ms"]
    rows = store.db.execute("SELECT recipient FROM version_recipients WHERE message_id=? AND version_ms=? ORDER BY recipient",
                            (message["message_id"], stamp)).fetchall()
    if rows:
        return [r[0] for r in rows]
    original = store.db.execute("SELECT sent_ms FROM messages WHERE message_id=?", (message["message_id"],)).fetchone()[0]
    if stamp == original:
        rows = store.db.execute("SELECT recipient FROM message_recipients WHERE message_id=? ORDER BY recipient", (message["message_id"],)).fetchall()
        if rows:
            return [r[0] for r in rows]
    conversation = store.db.execute("SELECT kind,target FROM conversations WHERE conversation_id=?",
                                    (message["conversation_id"],)).fetchone()
    # The pinned sent-sync serializer omits the group's sending audience. Never
    # substitute today's members or the first reporting member for that audience.
    return [conversation["target"]] if conversation["kind"] != "group" else []


def summary(store, account, message):
    peers = recipients(store, message) if message["direction"] == "outgoing" else []
    reports = {r: {} for r in peers}
    if peers and message["sent_ms"] is not None:
        for row in store.db.execute("SELECT recipient,kind,event_ms FROM receipt_reports WHERE account_id=? AND target_ms=?",
                                    (account, message["edited_ms"] or message["sent_ms"])):
            if row["recipient"] in reports:
                reports[row["recipient"]][row["kind"]] = row["event_ms"]
    counts = {"delivered": 0, "read": 0, "viewed": 0}
    details = []
    for peer, times in reports.items():
        rank = max((RANK[k] for k in times), default=0)
        counts["delivered"] += rank >= 1
        counts["read"] += rank >= 2
        counts["viewed"] += rank >= 3
        details.append({"serviceId": peer, "deliveryTimestampMs": times.get("delivery"),
                        "readTimestampMs": times.get("read"), "viewedTimestampMs": times.get("viewed")})
    status = message["status"]
    if status == "sent" and peers:
        for kind in ("delivered", "read", "viewed"):
            if counts[kind] == len(peers):
                status = kind
    return {"status": status, "receiptSummary": {**counts, "total": len(peers) if peers else None},
            "receipts": details}


def apply_message(store, account, mid):
    row = store.db.execute("SELECT * FROM messages WHERE message_id=?", (mid,)).fetchone()
    if row["sent_ms"] is None:
        return
    if row["direction"] == "outgoing":
        store.db.executemany("UPDATE receipt_reports SET expires_at_ms=NULL WHERE account_id=? AND recipient=? AND target_ms=?",
                            [(account, peer, v[0]) for peer in recipients(store, row)
                             for v in store.db.execute("SELECT version_ms FROM message_versions WHERE message_id=?", (mid,))])
        return
    marker = store.db.execute("SELECT read_ms FROM read_markers WHERE account_id=? AND author=? AND target_ms IN (SELECT version_ms FROM message_versions WHERE message_id=?) ORDER BY read_ms ASC LIMIT 1",
                              (account, row["author"], mid)).fetchone()
    if marker:
        signal_retention.start(store, account, mid, marker[0])
        store.db.execute("UPDATE read_markers SET expires_at_ms=NULL WHERE account_id=? AND author=? AND target_ms IN (SELECT version_ms FROM message_versions WHERE message_id=?)",
                         (account, row["author"], mid))
        if row["read_at_ms"] is None:
            store.db.execute("UPDATE messages SET read_at_ms=? WHERE message_id=?", (marker[0], mid))
            store.notify_message(account, mid)
            store.changed("conversation.changed", accountId=account, conversationId=row["conversation_id"])
            store.changed("message.read", accountId=account, conversationId=row["conversation_id"], messageId=mid)


def receive(store, account, event):
    db = store.db
    kind, author, target = event["kind"], event["author"], event["target_ms"]
    # A number/PNI is not an ACI; do not match by display name, number or time alone.
    if not author.startswith("aci:"):
        return
    if kind == "read_sync":
        db.execute("""INSERT INTO read_markers VALUES(?,?,?,?,?) ON CONFLICT(account_id,author,target_ms)
            DO UPDATE SET read_ms=MIN(read_ms,excluded.read_ms)""",
                   (account, author, target, event["event_ms"], store.clock() + TTL))
        db.execute("DELETE FROM read_queue WHERE account_id=? AND author=? AND target_ms=?", (account, author, target))
        rows = db.execute("""SELECT m.* FROM messages m JOIN conversations c USING(conversation_id)
            WHERE c.account_id=? AND m.author=? AND EXISTS(SELECT 1 FROM message_versions v WHERE v.message_id=m.message_id AND v.version_ms=?) AND m.direction='incoming'""", (account, author, target)).fetchall()
    else:
        old = db.execute("SELECT event_ms FROM receipt_reports WHERE account_id=? AND recipient=? AND target_ms=? AND kind=?",
                         (account, author, target, kind)).fetchone()
        if old and old[0] >= event["event_ms"]:
            return
        db.execute("""INSERT INTO receipt_reports VALUES(?,?,?,?,?,?) ON CONFLICT(account_id,recipient,target_ms,kind)
            DO UPDATE SET event_ms=MAX(event_ms,excluded.event_ms)""",
                   (account, author, target, kind, event["event_ms"], store.clock() + TTL))
        own = store.account(account)["service_id"]
        rows = db.execute("""SELECT m.* FROM messages m JOIN conversations c USING(conversation_id)
            WHERE c.account_id=? AND m.author=? AND EXISTS(SELECT 1 FROM message_versions v WHERE v.message_id=m.message_id AND v.version_ms=?) AND m.direction='outgoing'""", (account, own, target)).fetchall()
        rows = [r for r in rows if author in recipients(store, r)]
    for row in rows:
        apply_message(store, account, row["message_id"])
        if kind != "read_sync":
            store.notify_message(account, row["message_id"])
    pending = sum(db.execute("SELECT COUNT(*) FROM " + table + " WHERE expires_at_ms IS NOT NULL").fetchone()[0]
                  for table in ("receipt_reports", "read_markers"))
    if pending > 10000:
        raise Failure("overloaded")


def mark_visible(store, account, params):
    cid = params.get("conversationId")
    store.conversation(account, cid)
    if not store.conversation_item(account, cid)["canRead"]:
        return {"messageIds": []}
    ids = params.get("messageIds")
    through = params.get("throughMessageId")
    if through is not None:
        through = identifier(through)
        if ids is not None:
            raise Failure("invalid_request")
    else:
        if not isinstance(ids, list) or not 1 <= len(ids) <= 100:
            raise Failure("invalid_request")
        ids = list(dict.fromkeys(identifier(mid) for mid in ids))
    with store.transaction():
        rows = []
        more = False
        if through is not None:
            anchor = store.db.execute("SELECT sort_ms,message_id FROM messages WHERE message_id=? AND conversation_id=?", (through, cid)).fetchone()
            if not anchor:
                raise Failure("not_found")
            # Bound each transaction/response; the active view requests the next
            # batch using the same observed endpoint, never a moving timestamp.
            rows = store.db.execute("""SELECT * FROM messages WHERE conversation_id=?
                AND direction='incoming' AND read_at_ms IS NULL AND kind IN ('text','media')
                AND (sort_ms,message_id)<=(?,?) ORDER BY sort_ms,message_id LIMIT 101""",
                                    (cid, anchor["sort_ms"], anchor["message_id"])).fetchall()
            more = len(rows) > 100
            rows = rows[:100]
        else:
            for mid in ids:
                row = store.db.execute("SELECT * FROM messages WHERE message_id=? AND conversation_id=?", (mid, cid)).fetchone()
                if not row:
                    raise Failure("not_found")
                rows.append(row)
        marked = []
        for row in rows:
            if row["direction"] != "incoming" or row["read_at_ms"] is not None or row["kind"] not in ("text", "media"):
                continue
            now = integer(store.clock())
            store.db.execute("UPDATE messages SET read_at_ms=? WHERE message_id=?", (now, row["message_id"]))
            # Unresolved senders can be read locally, but cannot produce safe sync.
            if row["author"].startswith("aci:") and row["sent_ms"] is not None:
                store.db.execute("INSERT OR IGNORE INTO read_markers VALUES(?,?,?,?,NULL)",
                                 (account, row["author"], row["edited_ms"] or row["sent_ms"], now))
                store.db.execute("INSERT OR IGNORE INTO read_queue VALUES(?,?,?,'queued')",
                                 (account, row["author"], row["edited_ms"] or row["sent_ms"]))
            signal_retention.start(store, account, row["message_id"], now)
            marked.append(row["message_id"])
            store.notify_message(account, row["message_id"])
            store.changed("message.read", accountId=account, conversationId=cid, messageId=row["message_id"])
        if marked:
            store.changed("conversation.changed", accountId=account, conversationId=cid)
    return {"messageIds": marked, **({"hasMore": more} if through is not None else {})}


def next_batch(store, account):
    for row in store.db.execute("SELECT q.author,q.target_ms,m.conversation_id FROM read_queue q JOIN messages m ON m.author=q.author JOIN conversations c USING(conversation_id) WHERE q.account_id=? AND c.account_id=q.account_id AND q.state='queued' AND (m.sent_ms=q.target_ms OR m.edited_ms=q.target_ms)", (account,)).fetchall():
        if not store.conversation_item(account, row['conversation_id'])['canRead']:
            store.db.execute("DELETE FROM read_queue WHERE account_id=? AND author=? AND target_ms=?", (account, row['author'], row['target_ms']))
    first = store.db.execute("SELECT author FROM read_queue WHERE account_id=? AND state='queued' ORDER BY target_ms LIMIT 1", (account,)).fetchone()
    if not first:
        return None
    rows = store.db.execute("SELECT target_ms FROM read_queue WHERE account_id=? AND author=? AND state='queued' ORDER BY target_ms LIMIT 100",
                            (account, first[0])).fetchall()
    return {"account": store.account(account)["cli_address"], "recipient": first[0].removeprefix("aci:"),
            "targetTimestamp": [r[0] for r in rows], "type": "read"}


def batch_state(store, account, batch, state):
    with store.transaction():
        store.db.executemany("UPDATE read_queue SET state=? WHERE account_id=? AND author=? AND target_ms=?",
                            [(state, account, "aci:" + batch["recipient"], t) for t in batch["targetTimestamp"]])


def finish_batch(store, account, batch, result, error):
    # CLI reports only the external send result, not an acknowledgement of the
    # self-sync. Empty results are valid when external read receipts are disabled.
    state = "unknown"
    if error is None:
        try:
            integer(result["timestamp"], minimum=1)
            values = result["results"]
            if not isinstance(values, list) or len(values) > 1:
                raise ValueError()
            for value in values:
                if service_id(value["recipientAddress"]["uuid"]) != "aci:" + batch["recipient"]:
                    raise ValueError()
            state = "submitted" if all(v["type"] == "SUCCESS" for v in values) else "failed"
        except (KeyError, TypeError, ValueError, Failure):
            pass
    batch_state(store, account, batch, state)
