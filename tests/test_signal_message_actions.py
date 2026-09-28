"""Message pin and forward behavior on private history and synthetic transport."""
import asyncio
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
import uuid
import time

import test_signal_history as history
import test_signal_media as media_tests
from signal_events import normalize
from signal_forward import forward
from signal_transport import Failure
import signal_pins
import signal_retention


def pin_event(stamp, target, *, remove=False, author=history.PEER, group=None, duration=86400):
    wire = history.event(timestamp=stamp, group=group)
    data = wire['params']['result']['envelope']['dataMessage']
    data.pop('message', None)
    data['unpinMessage' if remove else 'pinMessage'] = {
        'targetAuthorUuid': author, 'targetSentTimestamp': target, 'pinDurationSeconds': duration}
    return wire


class PinsTests(unittest.TestCase):
    setUp = history.HistoryTests.setUp
    tearDown = history.HistoryTests.tearDown
    committed = history.HistoryTests.committed
    conversation = history.HistoryTests.conversation
    messages = history.HistoryTests.messages
    reopen = history.HistoryTests.reopen

    def message(self, stamp=None, group=None):
        stamp = stamp or self.now - 2000
        self.store.receive(self.account, history.event(timestamp=stamp, group=group))
        cid = self.conversation('group', history.GROUP) if group else self.conversation()
        return self.messages(cid)[0]

    def test_pin_rpc_duration_unpin_and_restart(self):
        row = self.message()
        params = {'conversationId': row['conversationId'], 'messageId': row['messageId'],
                  'versionTimestampMs': row['versionTimestampMs'], 'durationSeconds': 604800}
        op = self.outbox.mutations.enqueue(self.account, params, 'pin')
        self.assertEqual(self.outbox.rpc_method(self.account, op['operationId']), 'sendPinMessage')
        fields, attempt = self.outbox.begin(self.account, op['operationId'])
        self.assertEqual(fields['pinDuration'], 604800)
        self.assertEqual(fields['targetTimestamp'], row['versionTimestampMs'])
        self.assertEqual(fields['targetAuthor'], history.PEER)
        self.outbox.finish(self.account, op['operationId'], attempt, history.send_result(self.now))
        self.assertTrue(self.store.message(self.account, row['messageId'])['pinned'])
        self.reopen()
        self.assertEqual(len(self.store.conversation_item(self.account, row['conversationId'])['pinnedMessages']), 1)
        op = self.outbox.mutations.enqueue(self.account, params, 'unpin')
        self.assertEqual(self.outbox.rpc_method(self.account, op['operationId']), 'sendUnpinMessage')
        fields, attempt = self.outbox.begin(self.account, op['operationId'])
        self.assertNotIn('pinDuration', fields)
        self.outbox.finish(self.account, op['operationId'], attempt, history.send_result(self.now + 1))
        self.assertFalse(self.store.message(self.account, row['messageId'])['pinned'])

    def test_remote_pins_limit_duplicates_order_expiry_and_no_history(self):
        mids = []
        for n in range(4):
            row = self.message(self.now - 2000 + n)
            mids.append(row['messageId'])
            wire = pin_event(self.now + n, row['sentTimestampMs'])
            self.store.receive(self.account, wire)
            self.store.receive(self.account, wire)
        cid = row['conversationId']
        self.assertEqual([p['messageId'] for p in signal_pins.listed(self.store, cid)], mids[1:])
        self.assertEqual(len(self.messages(cid)), 4)
        self.now += 86400001
        with self.store.transaction():
            self.store.cleanup()
        self.assertEqual(signal_pins.listed(self.store, cid), [])
        self.assertFalse(self.store.message(self.account, mids[-1])['pinned'])

    def test_deleted_targets_and_group_permissions_do_not_allow_pinning(self):
        row = self.message(group=history.GROUP)
        data = self.store.directory(self.account)
        data['groups'][0]['canEdit'] = False
        self.store.db.execute('UPDATE store_metadata SET value=? WHERE key=?',
            (json.dumps(data), 'directory:' + self.account))
        self.assertFalse(self.store.message(self.account, row['messageId'])['canPin'])
        with self.assertRaisesRegex(Failure, 'pin_unavailable'):
            self.outbox.mutations.enqueue(self.account, {'conversationId': row['conversationId'],
                'messageId': row['messageId'], 'versionTimestampMs': row['versionTimestampMs'], 'durationSeconds': -1}, 'pin')
        direct = self.message(self.now - 1000)
        signal_retention.local_delete(self.store, self.account, {'conversationId': direct['conversationId'], 'messageId': direct['messageId']})
        self.store.receive(self.account, pin_event(self.now, direct['sentTimestampMs']))
        self.assertEqual(signal_pins.listed(self.store, direct['conversationId']), [])

    def test_pin_on_sync_copy_survives_own_send_confirmation(self):
        cid = self.conversation()
        op = self.outbox.enqueue(self.account, {'conversationId': cid, 'text': 'Reply'})
        _, attempt = self.outbox.begin(self.account, op['operationId'])
        self.store.receive(self.account, history.event('sent-sync', timestamp=self.now, body='Reply'))
        self.store.receive(self.account, pin_event(self.now + 1, self.now, author=history.OWN))
        self.outbox.finish(self.account, op['operationId'], attempt, history.send_result(self.now))
        self.assertEqual([p['messageId'] for p in signal_pins.listed(self.store, cid)], [op['messageId']])
        self.assertEqual(len(self.messages(cid)), 1)

    def test_remote_group_pin_requires_edit_permission_and_failed_send_is_not_optimistic(self):
        row = self.message(group=history.GROUP)
        data = self.store.directory(self.account)
        group = data['groups'][0]
        group.update(permissionEditDetails='ONLY_ADMINS', permissionSendMessage='EVERY_MEMBER')
        self.store.db.execute('UPDATE store_metadata SET value=? WHERE key=?', (json.dumps(data), 'directory:' + self.account))
        self.store.receive(self.account, pin_event(self.now, row['sentTimestampMs'], group=history.GROUP))
        self.assertEqual(signal_pins.listed(self.store, row['conversationId']), [])
        group['members'][0]['isAdmin'] = True
        self.store.db.execute('UPDATE store_metadata SET value=? WHERE key=?', (json.dumps(data), 'directory:' + self.account))
        self.store.receive(self.account, pin_event(self.now + 1, row['sentTimestampMs'], group=history.GROUP))
        self.assertTrue(self.store.message(self.account, row['messageId'])['pinned'])
        row = self.message(self.now - 1000)
        op = self.outbox.mutations.enqueue(self.account, {'conversationId': row['conversationId'],
            'messageId': row['messageId'], 'versionTimestampMs': row['versionTimestampMs'], 'durationSeconds': -1}, 'pin')
        _, attempt = self.outbox.begin(self.account, op['operationId'])
        self.outbox.finish(self.account, op['operationId'], attempt, None, Failure('transport_closed'))
        self.assertFalse(self.store.message(self.account, row['messageId'])['pinned'])
        self.assertEqual(self.outbox.status(self.account, op['operationId'])['state'], 'unknown')
        with self.assertRaisesRegex(Failure, 'retry_unsafe'):
            self.outbox.retry(self.account, op['operationId'])


class ForwardTests(unittest.IsolatedAsyncioTestCase):
    committed = history.HistoryTests.committed
    conversation = history.HistoryTests.conversation
    messages = history.HistoryTests.messages
    enqueue = history.HistoryTests.enqueue

    async def asyncSetUp(self):
        history.HistoryTests.setUp(self)
        async def worker(function, *args, **kwargs):
            return function(*args, **kwargs)
        self.bridge = SimpleNamespace(store=self.store, account_id=self.account, account_state='linked',
            state='ready', media_lock=asyncio.Lock(), outbox=self.outbox, media_worker=worker,
            wake_outbox=asyncio.Event(), schedule_cleanup=lambda: None)
        self.source = self.conversation()
        self.destination = self.conversation(target=history.OTHER)
        self.store.receive(self.account, history.event(timestamp=self.now - 2000, body='Forwarded text'))
        self.row = self.messages(self.source)[0]
        self.params = {'accountId': self.account, 'conversationId': self.source, 'targetConversationId': self.destination,
            'messages': [{'messageId': self.row['messageId'], 'versionTimestampMs': self.row['versionTimestampMs'],
                          'operationId': str(uuid.uuid4())}]}

    async def asyncTearDown(self):
        history.HistoryTests.tearDown(self)

    async def test_forward_does_not_replace_draft_and_same_request_never_duplicates(self):
        self.store.set_draft(self.account, {'conversationId': self.destination, 'text': 'Keep my draft', 'expectedRevision': 0})
        result = await forward(self.bridge, self.params)
        repeated = await forward(self.bridge, self.params)
        self.assertEqual(result, repeated)
        rows = self.messages(self.destination)
        self.assertEqual([r['text'] for r in rows], ['Forwarded text'])
        self.assertEqual(self.store.draft(self.account, self.destination)['text'], 'Keep my draft')
        fields, _ = self.outbox.begin(self.account, result['operations'][0]['operationId'])
        self.assertEqual(fields['recipient'], [history.OTHER])
        self.assertEqual(fields['message'], 'Forwarded text')
        self.assertNotIn('quoteTimestamp', fields)

    async def test_failed_batch_is_atomic_and_rejects_stale_deleted_and_wrong_account(self):
        with self.assertRaisesRegex(Failure, 'account_mismatch'):
            await forward(self.bridge, {**self.params, 'accountId': 'another-account'})
        existing = self.enqueue(self.destination, 'Earlier local message')
        self.store.receive(self.account, history.event(timestamp=self.now - 1000, body='Second'))
        row = self.messages(self.source)[0]
        self.params['messages'].append({'messageId': row['messageId'], 'versionTimestampMs': row['versionTimestampMs'],
                                       'operationId': existing['operationId']})
        with self.assertRaisesRegex(Failure, 'operation_conflict'):
            await forward(self.bridge, self.params)
        self.assertEqual([r['text'] for r in self.messages(self.destination)], ['Earlier local message'])
        self.params['messages'] = self.params['messages'][:1]
        self.params['messages'][0]['versionTimestampMs'] += 1
        with self.assertRaisesRegex(Failure, 'version_conflict'):
            await forward(self.bridge, self.params)
        self.params['messages'][0]['versionTimestampMs'] -= 1
        signal_retention.local_delete(self.store, self.account, {'conversationId': self.source, 'messageId': self.row['messageId']})
        with self.assertRaisesRegex(Failure, 'message_unavailable'):
            await forward(self.bridge, self.params)

    async def test_forward_batch_dispatch_order_is_stable_for_identical_milliseconds(self):
        self.store.receive(self.account, history.event(timestamp=self.now - 1000, body='Second'))
        second = self.messages(self.source)[0]
        first_op, second_op = 'ffffffff-ffff-4fff-8fff-ffffffffffff', '00000000-0000-4000-8000-000000000000'
        params = {**self.params, 'messages': [
            {'messageId': self.row['messageId'], 'versionTimestampMs': self.row['versionTimestampMs'], 'operationId': first_op},
            {'messageId': second['messageId'], 'versionTimestampMs': second['versionTimestampMs'], 'operationId': second_op}]}
        await forward(self.bridge, params)
        self.assertEqual(self.outbox.next(self.account), first_op)
        self.outbox.begin(self.account, first_op)
        self.assertEqual(self.outbox.next(self.account), second_op)

    async def test_media_forward_has_independent_files_and_expiration_does_not_remove_it(self):
        source = media_tests.png(self.base / 'synthetic.png')
        attachments = media_tests.MediaTests.stage(self, self.source, [source])
        op = self.enqueue(self.source, 'Image', attachmentIds=[attachments[0]['attachment_id']])
        _, attempt = self.outbox.begin(self.account, op['operationId'])
        self.outbox.finish(self.account, op['operationId'], attempt, history.send_result(self.now))
        row = self.store.message(self.account, op['messageId'])
        params = {**self.params, 'messages': [{'messageId': row['messageId'], 'versionTimestampMs': row['versionTimestampMs'], 'operationId': str(uuid.uuid4())}]}
        result = await forward(self.bridge, params)
        copied = self.store.message(self.account, result['operations'][0]['messageId'])
        self.assertNotEqual(copied['attachments'][0]['attachment_id'], row['attachments'][0]['attachment_id'])
        from signal_media import local_path
        copied_path = local_path(copied['attachments'][0]['url'])
        self.assertEqual(Path(copied_path).read_bytes(), source.read_bytes())
        signal_retention.local_delete(self.store, self.account, {'conversationId': self.source, 'messageId': row['messageId']})
        self.assertTrue(Path(copied_path).is_file())
        self.assertEqual(self.store.message(self.account, copied['messageId'])['attachments'][0]['state'], 'ready')
        self.assertEqual(self.store.draft(self.account, self.destination)['attachments'], [])

    prepare = media_tests.MediaTests.prepare


class ActionsBridgeTests(unittest.TestCase):
    setUp = history.BridgeHistoryTests.setUp
    tearDown = history.BridgeHistoryTests.tearDown
    start = history.BridgeHistoryTests.start
    request = history.BridgeHistoryTests.request
    operation = history.BridgeHistoryTests.operation

    def test_real_bridge_dispatches_pin_unpin_and_forward_once(self):
        stamp = int(time.time() * 1000) - 10000
        client = self.start(receiveEvents=[history.event(timestamp=stamp)], interactionTimestamp=stamp + 2000,
            sendResult=history.send_result(stamp + 3000))
        state = client.state('ready')
        cid = self.request(client, 'conversations.page')['items'][0]['conversationId']
        message = self.request(client, 'messages.page', {'conversationId': cid})['items'][0]
        params = {'conversationId': cid, 'messageId': message['messageId'], 'versionTimestampMs': stamp, 'durationSeconds': 604800}
        for remove in (False, True):
            op = self.request(client, 'message.pin', {**params, 'remove': remove, 'operationId': str(uuid.uuid4())})
            self.operation(client, op['operationId'], 'sent')
            value = self.request(client, 'message.get', {'messageId': message['messageId']})
            self.assertEqual(value['pinned'], not remove)
        params = {'accountId': state['data']['accountId'], 'conversationId': cid, 'targetConversationId': cid, 'messages': [{
            'messageId': message['messageId'], 'versionTimestampMs': stamp, 'operationId': str(uuid.uuid4())}]}
        result = self.request(client, 'message.forward', params)
        self.operation(client, result['operations'][0]['operationId'], 'sent')
        self.request(client, 'message.forward', params)
        self.assertEqual(len(self.request(client, 'messages.page', {'conversationId': cid})['items']), 2)
        client.close()
        records = [json.loads(line) for line in self.record.read_text().splitlines()]
        self.assertEqual([r['kind'] for r in records if r['kind'] in ('pin', 'unpin', 'send')], ['pin', 'unpin', 'send'])


if __name__ == '__main__':
    unittest.main()
