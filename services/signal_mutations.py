"""Durable edits/reactions dispatched by the same sender as message.send."""
import json
import uuid
import signal_retention
from signal_content import emoji, send_fields
from signal_events import identifier, integer, service_id, text
import signal_interactions as interactions
from signal_transport import Failure

DEFINITE = {'UNREGISTERED_FAILURE', 'IDENTITY_FAILURE', 'RATE_LIMIT_FAILURE', 'INVALID_PRE_KEY_FAILURE'}


class Mutations:
    def __init__(self, outbox):
        self.outbox, self.store, self.db = outbox, outbox.store, outbox.db

    def row(self, account, op):
        return self.db.execute('SELECT * FROM interaction_outbox WHERE account_id=? AND operation_id=?', (account, identifier(op))).fetchone()

    def status(self, row):
        return {'operationId': row['operation_id'], 'conversationId': row['conversation_id'], 'messageId': row['message_id'],
                'kind': row['kind'], 'state': row['state'], 'errorCode': row['error_code'], 'safeRetry': bool(row['safe_retry']), 'attempt': row['attempt'], 'recipients': []}

    def validate(self, account, row, kind):
        # A queued operation excludes itself in the public canEdit/canReact.
        if row['kind'] not in ('text', 'media') or row['sent_ms'] is None:
            raise Failure('message_unavailable')
        if not self.store.conversation_item(account, row['conversation_id'])['canSend']:
            raise Failure('send_unavailable')
        if kind == 'delete':
            if not signal_retention.can_remote_delete(self.store, account, row):
                raise Failure('delete_unavailable')
        elif kind == 'edit':
            count = self.db.execute('SELECT COUNT(*) FROM message_versions WHERE message_id=? AND target_ms IS NOT NULL', (row['message_id'],)).fetchone()[0]
            note = self.store.conversation(account, row['conversation_id'])['kind'] == 'note'
            if row['author'] != self.store.account(account)['service_id'] or row['status'] != 'sent' or row['body'] is None:
                raise Failure('edit_unavailable')
            if count >= interactions.MAX_EDITS or (not note and not 0 <= self.store.clock() - row['sent_ms'] < interactions.EDIT_WINDOW):
                raise Failure('edit_limit')
        elif not row['author'].startswith('aci:'):
            raise Failure('message_unavailable')

    def enqueue(self, account, params, kind):
        mid, cid = identifier(params.get('messageId')), params.get('conversationId')
        self.store.conversation(account, cid)
        message = self.db.execute('SELECT * FROM messages WHERE conversation_id=? AND message_id=?', (cid, mid)).fetchone()
        if not message:
            raise Failure('not_found')
        op = identifier(params['operationId']) if 'operationId' in params else str(uuid.uuid4())
        target_ms = integer(params.get('versionTimestampMs'), minimum=1)
        payload = {'targetMs': target_ms, 'author': message['author']}
        if kind == 'edit':
            payload['text'] = text(params.get('text'), empty=False)
            if not payload['text'].strip():
                raise Failure('invalid_request')
            payload['metadata'] = interactions.compose_metadata(self.store, account, cid, params, payload['text'])
            # Edits preserve the existing quote and attachments.
            quote = interactions.current_meta(self.store, mid).get('quote')
            if quote:
                payload['metadata']['quote'] = quote
        elif kind == 'reaction':
            payload.update(emoji=emoji(params.get('emoji')), removed=params.get('remove') is True)
        encoded = interactions.encoded(payload)
        with self.store.transaction():
            self.store.cleanup()
            old = self.row(account, op)
            if old:
                if old['message_id'] != mid or old['kind'] != kind or old['payload'] != encoded:
                    raise Failure('operation_conflict')
                return self.status(old)
            if self.db.execute('SELECT 1 FROM outbox WHERE operation_id=?', (op,)).fetchone():
                raise Failure('operation_conflict')
            message = self.db.execute('SELECT * FROM messages WHERE message_id=?', (mid,)).fetchone()
            self.validate(account, message, kind)
            if target_ms != (message['edited_ms'] or message['sent_ms']):
                raise Failure('version_conflict')
            if self.db.execute("SELECT 1 FROM interaction_outbox WHERE message_id=? AND state IN ('queued','sending','unknown')", (mid,)).fetchone():
                raise Failure('operation_pending')
            if self.db.execute("SELECT COUNT(*) FROM interaction_outbox WHERE state='queued'").fetchone()[0] >= 1000:
                raise Failure('overloaded')
            self.db.execute('''INSERT INTO interaction_outbox(operation_id,account_id,conversation_id,message_id,kind,payload,state,created_ms,expires_at_ms)
                VALUES(?,?,?,?,?,?,'queued',?,?)''', (op, account, cid, mid, kind, encoded, self.store.clock(), self.store.clock() + 86400000))
            self.outbox.changed(self.row(account, op))
        return self.status(self.row(account, op))

    def begin(self, row):
        account, mid = row['account_id'], row['message_id']
        with self.store.transaction():
            self.store.cleanup()
            row = self.row(account, row['operation_id'])
            if row['state'] != 'queued':
                raise Failure('operation_not_queued')
            message = self.db.execute('SELECT * FROM messages WHERE message_id=?', (mid,)).fetchone()
            self.validate(account, message, row['kind'])
            payload = json.loads(row['payload'])
            if payload.get('targetMs') != (message['edited_ms'] or message['sent_ms']):
                raise Failure('version_conflict')
            conversation = self.store.conversation(account, row['conversation_id'])
            params = {'account': self.store.account(account)['cli_address']}
            if conversation['kind'] == 'group': params['groupId'] = [conversation['target']]
            elif conversation['kind'] == 'note': params['noteToSelf'] = True
            else: params['recipient'] = [conversation['target'].removeprefix('aci:')]
            if row['kind'] == 'edit':
                params.update(message=payload['text'], editTimestamp=payload['targetMs'], **send_fields(payload['metadata']))
                if message['kind'] == 'media':
                    params['attachment'] = self.store.media.send_paths(account, mid)
                    if not params['attachment']:
                        raise Failure('attachment_unavailable')
            elif row['kind'] == 'delete':
                params['targetTimestamp'] = payload['targetMs']
            else:
                params.update(emoji=payload['emoji'], remove=payload['removed'], targetAuthor=payload['author'].removeprefix('aci:'), targetTimestamp=payload['targetMs'])
            attempt = row['attempt'] + 1
            self.db.execute("UPDATE interaction_outbox SET state='sending',attempt=?,safe_retry=0,error_code='' WHERE operation_id=?", (attempt, row['operation_id']))
            self.outbox.changed(row)
        return params, attempt

    def fail(self, row, code, definite=False):
        if row['state'] in ('sent', 'cancelled'):
            return
        with self.store.transaction():
            self.db.execute('UPDATE interaction_outbox SET state=?,error_code=?,safe_retry=? WHERE operation_id=?',
                ('failed' if definite else 'unknown', code, bool(definite and code not in ('delete_unavailable','edit_limit','edit_unavailable','version_conflict','message_unavailable','retention_unsupported')), row['operation_id']))
            self.outbox.changed(row)

    def finish(self, row, attempt, result, error):
        if row['attempt'] != attempt or row['state'] not in ('sending', 'unknown'):
            return
        if error is not None:
            self.fail(row, 'result_unknown')
            return
        try:
            timestamp = integer(result['timestamp'], minimum=1)
            if row['kind'] == 'edit' and timestamp <= json.loads(row['payload']).get('targetMs', 0):
                raise ValueError()
            values = result['results']
            if not isinstance(values, list) or not 1 <= len(values) <= 1000:
                raise ValueError()
            peers = [service_id(v['recipientAddress']['uuid']) for v in values]
            conversation = self.store.conversation(row['account_id'], row['conversation_id'])
            if len(set(peers)) != len(peers) or (conversation['kind'] != 'group' and peers != [conversation['target']]):
                raise ValueError()
            kinds = [v['type'] for v in values]
        except (KeyError, TypeError, ValueError, Failure):
            self.fail(row, 'invalid_send_result')
            return
        if not all(k == 'SUCCESS' for k in kinds):
            # Partial effects cannot safely retry or display a universal success.
            self.fail(row, 'send_failed', definite=all(k in DEFINITE for k in kinds) and not any(v.get('retryAfterSeconds') for v in values))
            return
        with self.store.transaction():
            self.db.execute("UPDATE interaction_outbox SET state='sent',sent_ms=?,safe_retry=0,error_code='' WHERE operation_id=?", (timestamp, row['operation_id']))
            if row['kind'] == 'edit':
                self.db.executemany('INSERT OR IGNORE INTO version_recipients VALUES(?,?,?)', [(row['message_id'], timestamp, peer) for peer in peers])
            payload = json.loads(row['payload'])
            if row['kind'] == 'delete':
                self.store.redact(row['account_id'], row['conversation_id'], payload.get('author', self.store.account(row['account_id'])['service_id']),
                    payload.get('targetMs', self.db.execute('SELECT sent_ms FROM messages WHERE message_id=?', (row['message_id'],)).fetchone()[0]), 'deleted')
            elif payload:  # Retention can have removed content while RPC was inflight.
                event = {'kind': row['kind'], 'author': payload['author'], 'target_ms': payload['targetMs'], 'event_ms': timestamp}
                if row['kind'] == 'edit':
                    event.update(body=payload['text'], metadata=payload['metadata'], hidden=False)
                else:
                    event.update(actor=self.store.account(row['account_id'])['service_id'], emoji=payload['emoji'], removed=payload['removed'])
                interactions.receive(self.store, row['account_id'], row['conversation_id'], event)
            self.outbox.changed(row)

    def change(self, row, retry):
        with self.store.transaction():
            if retry:
                if row['state'] != 'failed' or not row['safe_retry'] or row['expires_at_ms'] <= self.store.clock():
                    raise Failure('retry_unsafe')
                if self.db.execute("SELECT 1 FROM interaction_outbox WHERE message_id=? AND operation_id!=? AND state IN ('queued','sending','unknown')", (row['message_id'], row['operation_id'])).fetchone():
                    raise Failure('operation_pending')
                state = 'queued'
            else:
                if row['state'] != 'queued':
                    raise Failure('operation_not_queued')
                state = 'cancelled'
            self.db.execute("UPDATE interaction_outbox SET state=?,safe_retry=0,error_code='' WHERE operation_id=?", (state, row['operation_id']))
            self.outbox.changed(row)
        return self.status(self.row(row['account_id'], row['operation_id']))
