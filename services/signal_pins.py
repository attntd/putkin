"""Signal pins: bounded projection, sender permissions, expiry and no content copy."""
import signal_interactions


def allowed(store, account, row, actor=None):
    if row['kind'] not in ('text', 'media') or row['sent_ms'] is None or row['hidden_local']:
        return False
    own = store.account(account)['service_id']
    actor = actor or own
    cid = row['conversation_id']
    conversation = store.conversation(account, cid)
    access = store.conversation_item(account, cid)
    if not access['canRead'] or (actor == own and not access['canSend']):
        return False
    if conversation['kind'] != 'group':
        return actor in (own, conversation['target'])
    group = next((g for g in store.directory(account)['groups'] if g['groupId'] == conversation['target']), {})
    if actor == own:
        return bool(group.get('canEdit'))
    members = {m['serviceId'] for m in group.get('members', [])}
    admins = {m['serviceId'] for m in group.get('admins', [])}
    admins.update(m['serviceId'] for m in group.get('members', []) if m.get('isAdmin'))
    return actor in members and (actor in admins or
        group.get('permissionEditDetails') == 'EVERY_MEMBER' and group.get('permissionSendMessage') == 'EVERY_MEMBER')


def listed(store, cid):
    return [dict(row) for row in store.db.execute("""
        SELECT m.message_id AS messageId,m.body AS text,m.author AS authorServiceId,
               p.expires_at_ms AS expiresAtMs,p.pin_order AS pinOrder
        FROM message_pins p JOIN messages m USING(message_id)
        WHERE m.conversation_id=? AND m.hidden_local=0 AND m.kind IN ('text','media')
          AND p.active=1 AND (p.expires_at_ms IS NULL OR p.expires_at_ms>?)
        ORDER BY p.pin_order LIMIT 3""", (cid, store.clock()))]


def receive(store, account, cid, event):
    row = signal_interactions.target(store, cid, event['author'], event['target_ms'])
    if row is None or not allowed(store, account, row, event['actor']):
        return  # Like Desktop, a pin cannot fabricate unavailable history.
    mid = row['message_id']
    old = store.db.execute('SELECT event_ms FROM message_pins WHERE message_id=?', (mid,)).fetchone()
    if old and old[0] >= event['event_ms']:
        return
    active = event['kind'] == 'pin'
    duration = event.get('duration', -1)
    expiry = store.clock() + duration * 1000 if active and duration > 0 else None
    order = store.next_message_order()
    store.db.execute("""INSERT INTO message_pins(message_id,event_ms,actor,active,expires_at_ms,pin_order)
        VALUES(?,?,?,?,?,?) ON CONFLICT(message_id) DO UPDATE SET
        event_ms=excluded.event_ms,actor=excluded.actor,active=excluded.active,
        expires_at_ms=excluded.expires_at_ms,pin_order=excluded.pin_order""",
        (mid, event['event_ms'], event['actor'], active, expiry, order))
    previous = store.db.execute("""SELECT p.message_id FROM message_pins p JOIN messages m USING(message_id)
        WHERE m.conversation_id=? AND p.active=1 ORDER BY p.pin_order DESC LIMIT -1 OFFSET 3""", (cid,)).fetchall()
    for item in previous:
        store.db.execute('UPDATE message_pins SET active=0,expires_at_ms=NULL WHERE message_id=?', (item[0],))
        store.notify_message(account, item[0])
    store.notify_message(account, mid)
    store.changed('conversation.changed', accountId=account, conversationId=cid)


def expire(store):
    rows = store.db.execute("""SELECT p.message_id,c.account_id,m.conversation_id
        FROM message_pins p JOIN messages m USING(message_id) JOIN conversations c USING(conversation_id)
        WHERE p.active=1 AND p.expires_at_ms<=?""", (store.clock(),)).fetchall()
    for row in rows:
        store.db.execute('UPDATE message_pins SET active=0,expires_at_ms=NULL WHERE message_id=?', (row['message_id'],))
        store.notify_message(row['account_id'], row['message_id'])
        store.changed('conversation.changed', accountId=row['account_id'], conversationId=row['conversation_id'])
