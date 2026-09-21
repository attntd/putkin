"""Version graph and reactions, keyed by conversation + ACI + protocol timestamp."""
import json
import signal_retention
from signal_content import ranges
from signal_events import integer
from signal_transport import Failure

TTL = 7 * 86400000
EDIT_WINDOW = 86400000
MAX_EDITS = 10


def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def target(store, cid, author, timestamp):
    return store.db.execute('''SELECT m.* FROM message_versions v JOIN messages m USING(message_id)
        WHERE v.conversation_id=? AND v.author=? AND v.version_ms=?''', (cid, author, timestamp)).fetchone()


def current_meta(store, mid):
    row = store.db.execute('SELECT payload FROM message_metadata WHERE message_id=?', (mid,)).fetchone()
    return json.loads(row[0]) if row else {}


def set_meta(store, mid, value):
    store.db.execute('INSERT INTO message_metadata VALUES(?,?) ON CONFLICT(message_id) DO UPDATE SET payload=excluded.payload', (mid, encoded(value)))


def base(store, mid, metadata=None):
    row = store.db.execute('SELECT * FROM messages WHERE message_id=?', (mid,)).fetchone()
    if row['sent_ms'] is None:
        return
    if metadata is not None:
        set_meta(store, mid, metadata)
    store.db.execute('''INSERT OR IGNORE INTO message_versions(conversation_id,author,version_ms,message_id,body,metadata,hidden)
        VALUES(?,?,?,?,?,?,?)''', (row['conversation_id'], row['author'], row['sent_ms'], mid, row['body'],
                                  encoded(current_meta(store, mid)), row['kind'] not in ('text', 'media')))


def receive(store, account, cid, event):
    db = store.db
    author, stamp, target_ms = event['author'], event['event_ms'], event['target_ms']
    if not author.startswith('aci:'):
        return
    if event['kind'] == 'edit':
        db.executemany('INSERT OR IGNORE INTO media_cli_gc VALUES(?)', [(aid,) for aid in event.get('attachment_ids', [])])
        if stamp <= target_ms:
            return
        row = target(store, cid, author, target_ms)
        hidden = bool(event.get('hidden') or (row and row['kind'] not in ('text', 'media')))
        hidden = hidden or bool(db.execute('SELECT 1 FROM tombstones WHERE conversation_id=? AND author=? AND sent_ms IN (?,?)', (cid, author, target_ms, stamp)).fetchone())
        body, meta = (None, '{}') if hidden else (event['body'], encoded(signal_retention.clean_metadata(store, cid, event['metadata'])))
        old = db.execute('SELECT * FROM message_versions WHERE conversation_id=? AND author=? AND version_ms=?', (cid, author, stamp)).fetchone()
        if old:
            if old['target_ms'] != target_ms or old['body'] != body or old['metadata'] != meta:
                if old['message_id']:
                    db.execute('UPDATE messages SET conflict=1 WHERE message_id=?', (old['message_id'],))
                    store.notify_message(account, old['message_id'])
            return
        db.execute('''INSERT INTO message_versions(conversation_id,author,version_ms,target_ms,body,metadata,hidden,expires_at_ms)
            VALUES(?,?,?,?,?,?,?,?)''', (cid, author, stamp, target_ms, body, meta, hidden, store.clock() + TTL))
    else:
        row = target(store, cid, author, target_ms)
        if row and row['kind'] not in ('text', 'media'):
            return
        if db.execute('SELECT 1 FROM tombstones WHERE conversation_id=? AND author=? AND sent_ms=?', (cid, author, target_ms)).fetchone():
            return
        actor = event['actor']
        if not actor or not actor.startswith('aci:'):
            return
        old = db.execute('SELECT * FROM message_reactions WHERE conversation_id=? AND author=? AND target_ms=? AND actor=?', (cid, author, target_ms, actor)).fetchone()
        if old and old['event_ms'] >= stamp:
            return
        db.execute('''INSERT INTO message_reactions VALUES(?,?,?,?,?,?,?,NULL,?)
            ON CONFLICT(conversation_id,author,target_ms,actor) DO UPDATE SET event_ms=excluded.event_ms,
            emoji=excluded.emoji,removed=excluded.removed''',
            (cid, author, target_ms, actor, stamp, event['emoji'], event['removed'], store.clock() + TTL))
        if old and old['message_id']:
            store.notify_message(account, old['message_id'])
    if event['kind'] == 'edit' and hidden:
        reason = db.execute('SELECT reason FROM tombstones WHERE conversation_id=? AND author=? AND sent_ms IN (?,?)', (cid, author, target_ms, stamp)).fetchone()
        if reason:
            store.redact(account, cid, author, stamp, reason[0])
    resolve(store, account, cid)
    pending = sum(db.execute('SELECT COUNT(*) FROM ' + table + ' WHERE message_id IS NULL').fetchone()[0]
                  for table in ('message_versions', 'message_reactions'))
    if pending > 10000:
        raise Failure('overloaded')


def resolve(store, account, cid):
    db = store.db
    # A version may target another version. Increasing timestamps make this a DAG.
    while True:
        rows = db.execute('''SELECT v.*,p.message_id AS resolved_id FROM message_versions v
            JOIN message_versions p ON p.conversation_id=v.conversation_id AND p.author=v.author AND p.version_ms=v.target_ms
            WHERE v.conversation_id=? AND v.message_id IS NULL AND p.message_id IS NOT NULL ORDER BY v.version_ms''', (cid,)).fetchall()
        if not rows:
            break
        for version in rows:
            mid = version['resolved_id']
            message = db.execute('SELECT * FROM messages WHERE message_id=?', (mid,)).fetchone()
            hidden = version['hidden'] or message['kind'] not in ('text', 'media')
            db.execute('UPDATE message_versions SET message_id=?,expires_at_ms=NULL,body=?,metadata=?,hidden=? WHERE conversation_id=? AND author=? AND version_ms=?',
                       (mid, None if hidden else version['body'], '{}' if hidden else version['metadata'], hidden, cid, version['author'], version['version_ms']))
            tombstone = db.execute('SELECT reason FROM tombstones WHERE conversation_id=? AND author=? AND sent_ms=?', (cid, version['author'], version['version_ms'])).fetchone()
            if tombstone:
                store.redact_message(account, mid, tombstone[0])
            elif hidden:
                if message['kind'] in ('text', 'media'):
                    store.redact_message(account, mid, 'expiring_unsupported')
            elif version['version_ms'] > (message['edited_ms'] or message['sent_ms']):
                # Never change sort time, original identity, unread count or expiry.
                db.execute('UPDATE messages SET body=?,edited_ms=? WHERE message_id=?', (version['body'], version['version_ms'], mid))
                set_meta(store, mid, json.loads(version['metadata']))
                store.notify_message(account, mid)
            refresh_quotes(store, account, cid, version['author'], version['version_ms'])
            # Old-version receipts remain attached to that version only.
            import signal_receipts
            signal_receipts.apply_message(store, account, mid)
    rows = db.execute('''SELECT r.*,v.message_id AS resolved_id FROM message_reactions r JOIN message_versions v
        ON r.conversation_id=v.conversation_id AND r.author=v.author AND r.target_ms=v.version_ms
        WHERE r.conversation_id=? AND r.message_id IS NULL AND v.message_id IS NOT NULL''', (cid,)).fetchall()
    for row in rows:
        db.execute('UPDATE message_reactions SET message_id=?,expires_at_ms=NULL WHERE conversation_id=? AND author=? AND target_ms=? AND actor=?',
                   (row['resolved_id'], cid, row['author'], row['target_ms'], row['actor']))
        store.notify_message(account, row['resolved_id'])


def refresh_quotes(store, account, cid, author, stamp):
    for row in store.db.execute("""SELECT m.message_id FROM message_metadata q JOIN messages m USING(message_id)
        WHERE m.conversation_id=? AND json_extract(q.payload,'$.quote.authorServiceId')=?
        AND json_extract(q.payload,'$.quote.timestampMs')=?""", (cid, author, stamp)).fetchall():
        store.notify_message(account, row['message_id'])


def actions(store, account, row):
    allowed = row['kind'] in ('text', 'media') and row['sent_ms'] is not None and row['author'].startswith('aci:')
    allowed = allowed and store.conversation_item(account, row['conversation_id'])['canSend']
    count = store.db.execute('SELECT COUNT(*) FROM message_versions WHERE message_id=? AND target_ms IS NOT NULL', (row['message_id'],)).fetchone()[0]
    conversation = store.conversation(account, row['conversation_id'])
    edit = allowed and row['author'] == store.account(account)['service_id'] and row['status'] == 'sent' and row['body'] is not None
    edit = edit and count < MAX_EDITS and (conversation['kind'] == 'note' or 0 <= store.clock() - row['sent_ms'] < EDIT_WINDOW)
    busy = store.db.execute("SELECT 1 FROM interaction_outbox WHERE message_id=? AND state IN ('queued','sending','unknown')", (row['message_id'],)).fetchone()
    return {'canReact': bool(allowed and not busy), 'canReply': bool(allowed), 'canEdit': bool(edit and not busy)}


def summary(store, account, row):
    mid = row['message_id']
    meta = current_meta(store, mid)
    quote = dict(meta['quote']) if meta.get('quote') else None
    if quote:
        original = target(store, row['conversation_id'], quote['authorServiceId'], quote['timestampMs'])
        quote['messageId'] = original['message_id'] if original and original['kind'] in ('text', 'media') else ''
        quote['available'] = bool(quote['messageId'])
        contact = next((c for c in store.directory(account)['contacts'] if c['serviceId'] == quote['authorServiceId']), {})
        quote['author'] = 'Ty' if quote['authorServiceId'] == store.account(account)['service_id'] else contact.get('name') or contact.get('profileName') or contact.get('number') or quote['authorServiceId']
    own = store.account(account)['service_id']
    directory = store.directory(account)
    names = {c['serviceId']: c.get('name') or c.get('profileName') or c.get('number') or c['serviceId'] for c in directory['contacts']}
    actors = {}
    if row['kind'] in ('text', 'media'):
        for r in store.db.execute('SELECT * FROM message_reactions WHERE message_id=? ORDER BY event_ms,target_ms', (mid,)):
            actors[r['actor']] = r
    groups = {}
    for actor, r in actors.items():
        if r['removed']:
            continue
        group = groups.setdefault(r['emoji'], {'emoji': r['emoji'], 'count': 0, 'mine': False, 'people': []})
        group['count'] += 1
        group['mine'] |= actor == own
        group['people'].append({'serviceId': actor, 'name': 'Ty' if actor == own else names.get(actor, actor)})
    operation = store.db.execute('SELECT operation_id,state,error_code,safe_retry,kind FROM interaction_outbox WHERE message_id=? ORDER BY created_ms DESC,rowid DESC LIMIT 1', (mid,)).fetchone()
    versions = []
    import signal_receipts
    for v in store.db.execute('SELECT version_ms,body FROM message_versions WHERE message_id=? ORDER BY version_ms DESC LIMIT 11', (mid,)):
        version_row = dict(row, sent_ms=v['version_ms'], edited_ms=None)
        receipts = signal_receipts.summary(store, account, version_row)
        versions.append({'timestampMs': v['version_ms'], 'status': receipts['status'], 'receiptSummary': receipts['receiptSummary']})
    return {**actions(store, account, row), 'editedTimestampMs': row['edited_ms'],
            'versionTimestampMs': row['edited_ms'] or row['sent_ms'], 'versions': versions,
            'quote': quote, 'mentions': meta.get('mentions', []), 'styles': meta.get('styles', []),
            'reactions': list(groups.values()), 'interaction': dict(operation) if operation else None}


def compose_metadata(store, account, cid, params, body):
    meta = {'mentions': ranges(body, params.get('mentions', []), mentions=True),
            'styles': ranges(body, params.get('styles', []))}
    if meta['mentions'] and store.conversation(account, cid)['kind'] != 'group':
        raise Failure('invalid_mention')
    if meta['mentions']:
        group = next((g for g in store.directory(account)['groups'] if g['groupId'] == store.conversation(account, cid)['target']), {})
        members = {v['serviceId'] for v in group.get('members', []) if v.get('serviceId')}
        if any(m['serviceId'] not in members for m in meta['mentions']):
            raise Failure('invalid_mention')
    if params.get('quoteMessageId'):
        original = store.message(account, params['quoteMessageId'])
        if original['conversationId'] != cid or not original['canReply']:
            raise Failure('quote_unavailable')
        meta['quote'] = {'timestampMs': original['versionTimestampMs'], 'authorServiceId': original['authorServiceId'], 'text': original['text'] or ''}
    return signal_retention.clean_metadata(store, cid, meta)


def purge(store, mid):
    store.db.execute("UPDATE message_versions SET body=NULL,metadata='{}',hidden=1 WHERE message_id=?", (mid,))
    store.db.execute('DELETE FROM message_metadata WHERE message_id=?', (mid,))
    store.db.execute('DELETE FROM message_reactions WHERE message_id=?', (mid,))
    store.db.execute("UPDATE interaction_outbox SET payload='{}',safe_retry=0,state=CASE WHEN state='queued' THEN 'cancelled' ELSE state END WHERE message_id=?", (mid,))
