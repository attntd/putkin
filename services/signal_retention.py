"""S09 retention reducer. Called in the owner's transaction; no extra daemon."""
import asyncio
import errno
import json
import os
import time

from signal_events import integer
from signal_transport import Failure

DELETE_WINDOW = 86400000
MAX_EXPIRATION = 4 * 7 * 86400
HIDDEN = ('deleted', 'expired')


def configure(store, account, cid, seconds, stamp):
    seconds, stamp = integer(seconds), integer(stamp)
    store.db.execute('''UPDATE conversations SET expiration_seconds=?,expiration_version=?
        WHERE conversation_id=? AND expiration_version<=?''', (seconds, stamp, cid, stamp))
    store.changed('conversation.changed', accountId=account, conversationId=cid)


def start(store, account, mid, stamp):
    """Earliest known start wins. Duplicate reads/edits never extend a timer."""
    row = store.db.execute('SELECT * FROM messages WHERE message_id=?', (mid,)).fetchone()
    if not row or row['kind'] in HIDDEN or not row['expiration_seconds'] or not stamp:
        return
    stamp = min(integer(stamp, minimum=1), integer(store.clock(), minimum=1))
    stamp = min(stamp, row['expiration_start_ms'] or stamp)
    due = stamp + row['expiration_seconds'] * 1000
    if row['expiration_start_ms'] is not None:
        due = min(due, row['expires_at_ms'] or due)
    store.db.execute('UPDATE messages SET expiration_start_ms=?,expires_at_ms=? WHERE message_id=?', (stamp, due, mid))
    if due <= store.clock():
        store.redact(account, row['conversation_id'], row['author'], row['sent_ms'], 'expired')
    else:
        store.notify_message(account, mid)


def clean_metadata(store, cid, meta):
    quote = meta.get('quote')
    if quote and store.db.execute('SELECT 1 FROM tombstones WHERE conversation_id=? AND author=? AND sent_ms=?',
            (cid, quote['authorServiceId'], quote['timestampMs'])).fetchone():
        meta = dict(meta, quote=dict(quote, text='', unavailable=True))
    return meta


def aliases(store, cid, author, stamp, reason):
    """Close both directions of known edit edges, even before the base arrives."""
    keys = {stamp}
    while True:
        previous = len(keys)
        for row in store.db.execute('SELECT version_ms,target_ms,message_id FROM message_versions WHERE conversation_id=? AND author=?', (cid, author)):
            if row['version_ms'] in keys or row['target_ms'] in keys:
                keys.add(row['version_ms'])
                if row['target_ms'] is not None:
                    keys.add(row['target_ms'])
                if row['message_id']:
                    keys.update(r[0] for r in store.db.execute('SELECT version_ms FROM message_versions WHERE message_id=?', (row['message_id'],)))
        if len(keys) == previous:
            break
    store.db.executemany('''INSERT INTO tombstones VALUES(?,?,?,?) ON CONFLICT(conversation_id,author,sent_ms)
        DO UPDATE SET reason=excluded.reason WHERE tombstones.reason NOT IN ('deleted','expired')''',
        [(cid, author, key, reason) for key in keys])
    return keys


def purge_copies(store, account, cid, author, stamps):
    from signal_interactions import encoded
    db = store.db
    for stamp in stamps:
        db.execute("UPDATE message_versions SET body=NULL,metadata='{}',hidden=1,expires_at_ms=NULL WHERE conversation_id=? AND author=? AND version_ms=?", (cid, author, stamp))
        db.execute('DELETE FROM message_reactions WHERE conversation_id=? AND author=? AND target_ms=?', (cid, author, stamp))
        db.execute('DELETE FROM pending_events WHERE conversation_id=? AND author=? AND target_ms=?', (cid, author, stamp))
    # No full-text index or content backups exist. Quotes are the other content
    # owners: current metadata, old versions and queued mutation payloads.
    for table, key, column in (('message_metadata', 'message_id', 'payload'),
                               ('message_versions', 'rowid', 'metadata'),
                               ('interaction_outbox', 'operation_id', 'payload')):
        for row in db.execute(f'SELECT {key} AS id,{column} AS value FROM {table}').fetchall():
            value = json.loads(row['value'])
            meta = value.get('metadata', {}) if table == 'interaction_outbox' else value
            quote = meta.get('quote')
            if not quote or quote.get('authorServiceId') != author or quote.get('timestampMs') not in stamps:
                continue
            # Same author/time in another conversation is a separate identity.
            owner = db.execute(f'SELECT conversation_id FROM {table} WHERE {key}=?', (row['id'],)).fetchone() if table != 'message_metadata' else db.execute('SELECT conversation_id FROM messages WHERE message_id=?', (row['id'],)).fetchone()
            if not owner or owner[0] != cid:
                continue
            meta['quote'] = dict(quote, text='', unavailable=True)
            db.execute(f'UPDATE {table} SET {column}=? WHERE {key}=?', (encoded(value), row['id']))
            if table == 'message_metadata':
                store.notify_message(account, row['id'])
    for row in db.execute('SELECT d.*,m.author,m.sent_ms FROM drafts d JOIN messages m ON json_extract(d.composition,\'$.quoteMessageId\')=m.message_id WHERE m.conversation_id=?', (cid,)).fetchall():
        if row['author'] == author and row['sent_ms'] in stamps:
            composition = json.loads(row['composition']); composition.pop('quoteMessageId', None)
            db.execute('UPDATE drafts SET composition=?,revision=revision+1 WHERE conversation_id=?', (encoded(composition), row['conversation_id']))
            store.changed('draft.changed', accountId=account, conversationId=row['conversation_id'], revision=row['revision'] + 1, quoteRemoved=True)
    store.purged = True


def local_delete(store, account, params):
    mid, cid = params.get('messageId'), params.get('conversationId')
    message = store.message(account, mid)
    if message['conversationId'] != cid:
        raise Failure('not_found')
    with store.transaction():
        if message['sentTimestampMs'] is not None:
            store.redact(account, cid, message['authorServiceId'], message['sentTimestampMs'], 'deleted')
        else:
            store.redact_message(account, mid, 'deleted')
        store.db.execute('UPDATE messages SET hidden_local=1 WHERE message_id=?', (mid,))
        store.changed('message.removed', accountId=account, conversationId=cid, messageId=mid, replacementId='')
    return {'messageId': mid, 'scope': 'local'}


def can_remote_delete(store, account, row):
    return (row['kind'] in ('text', 'media') and row['author'] == store.account(account)['service_id']
            and row['status'] == 'sent' and row['sent_ms'] is not None
            and 0 <= store.clock() - row['sent_ms'] < DELETE_WINDOW)


class Deadline:
    """One absolute realtime timerfd; resume and wall-clock steps are events."""
    def __init__(self, due_ms, callback):
        self.loop = asyncio.get_running_loop()
        self.callback = callback
        self.fd = os.timerfd_create(time.CLOCK_REALTIME, flags=os.TFD_NONBLOCK | os.TFD_CLOEXEC)
        os.timerfd_settime_ns(self.fd, flags=os.TFD_TIMER_ABSTIME | os.TFD_TIMER_CANCEL_ON_SET,
                             initial=max(1, due_ms * 1000000))
        self.loop.add_reader(self.fd, self.ready)

    def ready(self):
        try:
            os.read(self.fd, 8)
        except OSError as error:
            if error.errno != errno.ECANCELED:
                raise
        self.cancel()
        self.callback()

    def cancel(self):
        if self.fd is not None:
            self.loop.remove_reader(self.fd)
            os.close(self.fd)
            self.fd = None
