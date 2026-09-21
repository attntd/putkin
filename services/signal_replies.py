"""Conversation-scoped quick replies; the full composer owns a separate draft."""
from signal_events import integer, text
from signal_transport import Failure


def draft(store, account, cid):
    store.conversation(account, cid)
    row = store.db.execute("SELECT * FROM reply_drafts WHERE conversation_id=?", (cid,)).fetchone()
    result = {"conversationId": cid, "text": row["body"] if row else "", "revision": row["revision"] if row else 0,
              "operationId": row["operation_id"] if row else None, "state": "", "safeRetry": False}
    if result["operationId"]:
        operation = store.db.execute("SELECT o.state,o.safe_retry,m.body FROM outbox o JOIN messages m USING(message_id) WHERE operation_id=?",
                                     (result["operationId"],)).fetchone()
        result.update(state=operation["state"], safeRetry=bool(operation["safe_retry"]),
                      text=(operation["body"] or "") if operation["state"] not in ("sent", "cancelled") else "")
    return result


def set_draft(store, account, params):
    cid, body, revision = params.get("conversationId"), text(params.get("text")), integer(params.get("expectedRevision"))
    with store.transaction():
        current = draft(store, account, cid)
        if current["revision"] != revision:
            raise Failure("draft_conflict")
        if current["operationId"] and current["state"] not in ("sent", "cancelled"):
            raise Failure("operation_in_progress")
        store.db.execute("""INSERT INTO reply_drafts VALUES(?,?,?,NULL) ON CONFLICT(conversation_id)
            DO UPDATE SET body=excluded.body,revision=excluded.revision,operation_id=NULL""", (cid, body, revision + 1))
        store.changed("reply.draft.changed", accountId=account, conversationId=cid, revision=revision + 1)
    return draft(store, account, cid)


def attach(store, account, params, operation):
    # Called inside enqueue's transaction, after INSERT of the existing outbox.
    cid = params.get("conversationId")
    current = draft(store, account, cid)
    if current["revision"] != integer(params.get("draftRevision")) or current["text"] != params["text"]:
        raise Failure("draft_conflict")
    if current["operationId"] and current["state"] not in ("sent", "cancelled"):
        raise Failure("operation_in_progress")
    store.db.execute("UPDATE reply_drafts SET body='',revision=revision+1,operation_id=? WHERE conversation_id=?", (operation, cid))
    store.changed("reply.draft.changed", accountId=account, conversationId=cid, revision=current["revision"] + 1)


def muted(store, cid):
    row = store.db.execute("SELECT muted FROM conversation_notifications WHERE conversation_id=?", (cid,)).fetchone()
    return bool(row and row[0])


def configure(store, account, params):
    cid, value = params.get("conversationId"), params.get("muted")
    store.conversation(account, cid)
    if type(value) is not bool:
        raise Failure("invalid_request")
    with store.transaction():
        store.db.execute("INSERT INTO conversation_notifications VALUES(?,?) ON CONFLICT(conversation_id) DO UPDATE SET muted=excluded.muted", (cid, value))
        store.changed("conversation.changed", accountId=account, conversationId=cid)
    return store.conversation_item(account, cid)
