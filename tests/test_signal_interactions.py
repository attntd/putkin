"""S08: protocol permutations, exact identities, real SQLite and RPC pipes."""
import copy
import json
import time
import unittest
import uuid

from test_signal_history import HistoryTests, BridgeHistoryTests, event, send_result, EVENTS, OWN, PEER, OTHER, GROUP
from test_signal_receipts import receipt
from signal_events import normalize
from signal_content import ranges, send_fields
from signal_transport import Failure
import signal_interactions as interactions

T = 1790000000000


def edit(target=T, stamp=T + 1000, body='Poprawiona 🐈', *, phone=False, group=None, author=PEER):
    wire = event('sent-sync' if phone else 'incoming', timestamp=stamp, body=body, group=group, author=OWN if phone else author)
    env = wire['params']['result']['envelope']
    if phone:
        data = env['syncMessage']['sentMessage']
        data['editMessage'] = {'targetSentTimestamp': target, 'dataMessage': dict(data)}
    else:
        data = env.pop('dataMessage')
        env['editMessage'] = {'targetSentTimestamp': target, 'dataMessage': data}
    return wire


def reaction(target=T, stamp=T + 2000, emoji='❤️', *, actor=PEER, author=PEER, remove=False, group=None, phone=False):
    wire = event('sent-sync' if phone else 'incoming', timestamp=stamp, group=group, author=OWN if phone else actor)
    env = wire['params']['result']['envelope']
    data = env.get('dataMessage') or env['syncMessage']['sentMessage']
    data['message'] = None
    data['reaction'] = {'emoji': emoji, 'targetAuthorUuid': author, 'targetSentTimestamp': target, 'isRemove': remove}
    return wire


def typing(stamp=T, active=True, group=None):
    wire = event()
    env = wire['params']['result']['envelope']
    env.pop('dataMessage')
    env['typingMessage'] = {'timestamp': stamp, 'action': 'STARTED' if active else 'STOPPED'}
    if group:
        env['typingMessage']['groupId'] = group
    return wire


class InteractionTests(unittest.TestCase):
    setUp = HistoryTests.setUp
    tearDown = HistoryTests.tearDown
    reopen = HistoryTests.reopen
    conversation = HistoryTests.conversation
    messages = HistoryTests.messages
    committed = HistoryTests.committed
    enqueue = HistoryTests.enqueue

    def message(self, mid):
        return self.store.message(self.account, mid)

    def base_message(self, *, phone=False, group=None, timestamp=T, body='Baza'):
        self.store.receive(self.account, event('sent-sync' if phone else 'incoming', timestamp=timestamp, body=body, group=group))
        cid = self.conversation('group', GROUP) if group else self.conversation()
        return self.messages(cid)[0]

    def mutation(self, message, kind='edit', **extra):
        return self.outbox.mutations.enqueue(self.account, {'messageId': message['messageId'], 'conversationId': message['conversationId'],
            'versionTimestampMs': message['versionTimestampMs'], 'text': 'Nowa treść', 'emoji': '👩‍💻', **extra}, kind)

    def finish(self, op, stamp=T + 4000, kind='SUCCESS'):
        params, attempt = self.outbox.begin(self.account, op['operationId'])
        self.outbox.finish(self.account, op['operationId'], attempt, send_result(stamp, kind))
        return params

    def test_edit_chain_reverse_delivery_duplicates_authorship_and_restart(self):
        for group in (None, GROUP):
            with self.subTest(group=group):
                cid = self.conversation('group', GROUP) if group else self.conversation()
                latest = edit(T + 1000, T + 3000, 'Najnowsza', group=group)
                self.store.receive(self.account, latest)
                self.store.receive(self.account, edit(T, T + 1000, 'Pierwsza', group=group))
                self.assertEqual(self.messages(cid), [])
                self.reopen()
                base = self.base_message(group=group)
                mid = base['messageId']
                self.assertEqual(base['text'], 'Najnowsza')
                self.assertEqual(base['sortTimestampMs'], T)
                self.assertEqual(base['sentTimestampMs'], T)
                self.assertEqual(len(base['versions']), 3)
                self.changes.clear()
                self.store.receive(self.account, latest)
                self.assertEqual(self.changes, [])
                self.store.receive(self.account, edit(T, T + 2000, 'Spóźniona', group=group))
                self.store.receive(self.account, edit(T, T + 4000, 'Inny autor', group=group, author=OTHER))
                self.assertEqual(self.message(mid)['text'], 'Najnowsza')
                self.assertEqual(self.store.conversation_item(self.account, cid)['unreadCount'], 1)
                self.assertEqual(len(self.messages(cid)), 1)

    def test_reactions_actor_key_change_remove_zwj_before_target_and_alias(self):
        self.store.receive(self.account, reaction(group=GROUP, emoji='👩‍💻'))
        self.store.receive(self.account, reaction(group=GROUP, emoji='👩‍💻', actor=OTHER))
        message = self.base_message(group=GROUP)
        mid = message['messageId']
        self.assertEqual(message['reactions'][0]['count'], 2)
        self.store.receive(self.account, edit(group=GROUP))
        self.store.receive(self.account, reaction(T + 1000, T + 5000, '👍🏽', actor=OTHER, group=GROUP))
        self.store.receive(self.account, reaction(T, T + 4000, '😂', actor=OTHER, group=GROUP))
        self.assertEqual({r['emoji'] for r in self.message(mid)['reactions']}, {'👩‍💻', '👍🏽'})
        self.store.receive(self.account, reaction(T + 1000, T + 6000, '👍🏽', actor=OTHER, remove=True, group=GROUP))
        self.reopen()
        self.assertEqual(self.message(mid)['reactions'][0]['count'], 1)
        self.store.receive(self.account, reaction(group=GROUP, emoji='👩‍💻', actor=OTHER))
        self.assertEqual(self.message(mid)['reactions'][0]['count'], 1)

    def test_phone_edits_reactions_do_not_toast_and_old_receipt_not_latest_read(self):
        message = self.base_message(phone=True)
        mid = message['messageId']
        self.store.receive(self.account, receipt('read', [T]))
        self.assertEqual(self.message(mid)['status'], 'read')
        self.changes.clear()
        self.store.receive(self.account, edit(phone=True))
        value = self.message(mid)
        self.assertEqual(value['status'], 'sent')
        self.assertEqual(value['versions'][1]['status'], 'read')
        self.store.receive(self.account, receipt('read', [T]))
        self.assertEqual(self.message(mid)['status'], 'sent')
        self.store.receive(self.account, receipt('read', [T + 1000]))
        self.assertEqual(self.message(mid)['status'], 'read')
        self.store.receive(self.account, reaction(T + 1000, author=OWN, phone=True))
        self.assertTrue(self.message(mid)['reactions'][0]['mine'])
        self.assertFalse(any(n == 'message.received' for n, _ in self.changes))

    def test_queue_applies_only_confirmed_result_preserves_draft_and_original_id(self):
        message = self.base_message(phone=True)
        cid, mid = message['conversationId'], message['messageId']
        self.store.set_draft(self.account, {'conversationId': cid, 'text': 'Zwykły szkic', 'expectedRevision': 0})
        op = self.mutation(message, operationId=str(uuid.uuid4()))
        self.assertEqual(self.message(mid)['text'], 'Baza')
        self.assertEqual(self.outbox.next(self.account), op['operationId'])
        params, attempt = self.outbox.begin(self.account, op['operationId'])
        self.assertEqual(params['editTimestamp'], T)
        self.assertEqual(self.message(mid)['text'], 'Baza')
        self.outbox.finish(self.account, op['operationId'], attempt, send_result(T + 4000))
        self.assertEqual(self.message(mid)['text'], 'Nowa treść')
        self.assertEqual(self.message(mid)['sortTimestampMs'], T)
        self.assertEqual(self.store.draft(self.account, cid)['text'], 'Zwykły szkic')
        self.assertEqual(self.message(mid)['interaction']['state'], 'sent')

    def test_error_known_failure_retry_unknown_no_repeat_and_operation_dedup(self):
        message = self.base_message(phone=True)
        opid = str(uuid.uuid4())
        op = self.mutation(message, operationId=opid)
        self.assertEqual(self.mutation(message, operationId=opid)['operationId'], opid)
        self.finish(op, kind='IDENTITY_FAILURE')
        self.assertEqual(self.message(message['messageId'])['text'], 'Baza')
        self.outbox.retry(self.account, opid)
        self.assertEqual(self.outbox.status(self.account, opid)['attempt'], 1)
        self.finish(op)
        self.assertEqual(self.outbox.status(self.account, opid)['attempt'], 2)
        reaction_op = self.mutation(self.message(message['messageId']), 'reaction')
        _, attempt = self.outbox.begin(self.account, reaction_op['operationId'])
        self.outbox.finish(self.account, reaction_op['operationId'], attempt, None, {'code': -3})
        self.reopen()
        self.assertEqual(self.outbox.status(self.account, reaction_op['operationId'])['state'], 'unknown')
        with self.assertRaisesRegex(Failure, 'retry_unsafe'):
            self.outbox.retry(self.account, reaction_op['operationId'])
        self.assertEqual(self.message(message['messageId'])['reactions'], [])

    def test_phone_sync_before_result_settles_exact_version_once(self):
        message = self.base_message(phone=True)
        op = self.mutation(message)
        _, attempt = self.outbox.begin(self.account, op['operationId'])
        self.store.receive(self.account, edit(T, T + 4000, 'Nowa treść', phone=True))
        self.outbox.finish(self.account, op['operationId'], attempt, send_result(T + 4000))
        value = self.message(message['messageId'])
        self.assertEqual(len(value['versions']), 2)
        self.assertFalse(value['conflict'])

    def test_limits_author_permissions_and_stale_editor(self):
        incoming = self.base_message()
        with self.assertRaisesRegex(Failure, 'edit_unavailable'):
            self.mutation(incoming)
        outgoing = self.base_message(phone=True, timestamp=T + 10)
        self.now = T + 10 + 86400000
        with self.assertRaisesRegex(Failure, 'edit_limit'):
            self.mutation(outgoing)
        self.now = T + 100000
        for i in range(10):
            self.store.receive(self.account, edit(T + 10, T + 1000 + i, phone=True))
        self.assertFalse(self.message(outgoing['messageId'])['canEdit'])
        with self.assertRaisesRegex(Failure, 'edit_limit'):
            self.mutation(self.message(outgoing['messageId']))

    def test_quote_missing_original_resolves_without_fabricating_history(self):
        wire = event(timestamp=T + 2000, body='Odpowiedź')
        wire['params']['result']['envelope']['dataMessage']['quote'] = {'id': T, 'authorUuid': PEER, 'text': '<b>Brak historii</b>'}
        self.store.receive(self.account, wire)
        cid = self.conversation()
        quoted = self.messages(cid)[0]
        self.assertFalse(quoted['quote']['available'])
        self.assertEqual(len(self.messages(cid)), 1)
        self.base_message()
        value = self.message(quoted['messageId'])
        self.assertTrue(value['quote']['available'])
        op = self.enqueue(cid, 'Z cytatem', quoteMessageId=value['quote']['messageId'])
        params, _ = self.outbox.begin(self.account, op['operationId'])
        self.assertEqual(params['quoteTimestamp'], T)
        self.assertEqual(params['quoteAuthor'], PEER)
        self.assertEqual(params['quoteMessage'], 'Baza')

    def test_utf16_emoji_mentions_and_whitelisted_styles(self):
        body = '👩‍💻 @Alicja <script>'
        mention = {'start': 6, 'length': 7, 'serviceId': 'aci:' + PEER}
        self.assertEqual(ranges(body, [mention], mentions=True), [mention])
        with self.assertRaises(Failure): ranges(body, [dict(mention, start=1)], mentions=True)
        self.assertEqual(ranges(body, [{'start': 0, 'length': 5, 'style': 'HTML'}]), [])
        cid = self.conversation('group', GROUP)
        with self.store.transaction():
            self.store.db.execute('INSERT OR REPLACE INTO store_metadata VALUES(?,?)', ('directory:' + self.account,
                json.dumps({'contacts': [], 'groups': [{'groupId': GROUP, 'membership': 'member', 'canSend': True, 'members': [{'serviceId': 'aci:' + PEER}]}]})))
        op = self.enqueue(cid, body, mentions=[mention])
        params, _ = self.outbox.begin(self.account, op['operationId'])
        self.assertEqual(params['mention'], ['6:7:' + PEER])
        with self.assertRaisesRegex(Failure, 'invalid_mention'):
            self.enqueue(self.conversation(), body, mentions=[mention])

    def test_edits_keep_expiry_and_delete_version_clears_all_content(self):
        message = self.base_message()
        mid = message['messageId']
        with self.store.transaction():
            self.store.db.execute('UPDATE messages SET expires_at_ms=? WHERE message_id=?', (self.now + 999, mid))
        self.store.receive(self.account, edit())
        self.assertEqual(self.message(mid)['expiresAtMs'], self.now + 999)
        with self.store.transaction():
            self.store.redact(self.account, message['conversationId'], 'aci:' + PEER, T + 1000, 'deleted')
        self.store.receive(self.account, edit(T, T + 3000, 'Nie przywracaj'))
        self.assertIsNone(self.message(mid)['text'])
        self.assertEqual(self.store.db.execute('SELECT COUNT(*) FROM message_versions WHERE body IS NOT NULL').fetchone()[0], 0)

    def test_pending_edits_expire_and_typing_does_not_create_history(self):
        self.store.receive(self.account, edit())
        self.store.receive(self.account, typing(group=GROUP))
        self.assertEqual(len(self.store.page(self.account, {})['items']), 1)
        self.assertEqual(self.messages(self.conversation()), [])
        self.now += 8 * 86400000
        self.reopen()
        self.assertEqual(self.store.db.execute('SELECT COUNT(*) FROM message_versions').fetchone()[0], 0)

    def test_pinned_cli_typing_actions_are_valid_without_persistent_messages(self):
        # JsonTypingMessage serializes MessageEnvelope.Typing.Type.name().
        # Upstream 0.14.8 uses STARTED/STOPPED, not the sendTyping CLI flag.
        for active in (True, False):
            wire = typing(active=active)
            self.assertEqual(normalize(wire, 'aci:' + OWN)[0]['active'], active)
            self.store.receive(self.account, wire)
        self.assertEqual(self.store.db.execute('SELECT COUNT(*) FROM messages').fetchone()[0], 0)
        self.assertEqual(self.store.db.execute('SELECT COUNT(*) FROM conversations').fetchone()[0], 0)
        wire = typing()
        wire['params']['result']['envelope']['typingMessage']['action'] = 'START'
        with self.assertRaisesRegex(Failure, 'invalid_event'):
            self.store.receive(self.account, wire)

    def test_media_caption_edit_keeps_files(self):
        from test_signal_media import png
        cid = self.conversation()
        path = png(self.base / 'caption.png')
        prepared = self.store.media.prepare(path.as_uri(), str(uuid.uuid4()))
        self.store.media.active.add(prepared['id'])
        try:
            attachments = self.store.media.stage(self.account, cid, [prepared])['attachments']
        finally:
            self.store.media.active.remove(prepared['id'])
        op = self.enqueue(cid, 'Podpis', attachmentIds=[attachments[0]['attachment_id']])
        self.finish(op, T)
        message = self.message(op['messageId'])
        mutation = self.mutation(message)
        params = self.finish(mutation, T + 4000)
        self.assertEqual(len(params['attachment']), 1)
        self.assertEqual(self.message(op['messageId'])['attachments'][0]['attachment_id'], message['attachments'][0]['attachment_id'])

    def test_group_edit_versions_have_their_own_audience_and_partial_failure_is_unknown(self):
        message = self.base_message(phone=True, group=GROUP)
        op = self.mutation(message)
        _, attempt = self.outbox.begin(self.account, op['operationId'])
        result = send_result(T + 4000)
        result['results'].append({'recipientAddress': {'uuid': OTHER}, 'type': 'SUCCESS'})
        self.outbox.finish(self.account, op['operationId'], attempt, result)
        self.store.receive(self.account, receipt('read', [T + 4000]))
        value = self.message(message['messageId'])
        self.assertEqual(value['receiptSummary']['total'], 2)
        self.assertEqual(value['receiptSummary']['read'], 1)
        self.assertIsNone(value['versions'][1]['receiptSummary']['total'])
        op = self.mutation(value, 'reaction')
        _, attempt = self.outbox.begin(self.account, op['operationId'])
        result['results'][1]['type'] = 'IDENTITY_FAILURE'
        self.outbox.finish(self.account, op['operationId'], attempt, result)
        self.assertEqual(self.outbox.status(self.account, op['operationId'])['state'], 'unknown')
        self.assertFalse(self.message(message['messageId'])['reactions'])

    def test_quote_mentions_draft_composition_persists_and_send_clears_it(self):
        message = self.base_message(group=GROUP)
        cid = message['conversationId']
        composition = {'quoteMessageId': message['messageId'], 'mentions': [{'start': 3, 'length': 2, 'serviceId': 'aci:' + PEER}]}
        self.store.set_draft(self.account, {'conversationId': cid, 'text': '🐈 @A', 'expectedRevision': 0, 'composition': composition})
        self.reopen()
        self.assertEqual(self.store.draft(self.account, cid)['composition'], composition)
        self.store.set_draft(self.account, {'conversationId': cid, 'text': 'Bez wzmianki', 'expectedRevision': 1})
        self.assertNotIn('composition', self.store.draft(self.account, cid))

    def test_emoji_sequences_are_preserved_and_multi_cluster_input_is_rejected(self):
        from signal_content import emoji
        for value in ('❤️', '❤', '👩‍💻', '👍🏽', '🇵🇱', '1️⃣', '👨‍👩‍👧‍👦'):
            self.assertEqual(emoji(value), value)
        for value in ('ab', '👍👍', '👍 x', '👩‍', '<img>'):
            with self.assertRaises(Failure): emoji(value)

    def test_note_to_self_edits_after_24_hours_and_cancel_does_not_change_message(self):
        wire = event('sent-sync', timestamp=T, body='Notatka')
        wire['params']['result']['envelope']['syncMessage']['sentMessage']['destinationUuid'] = OWN
        self.store.receive(self.account, wire)
        cid = self.store.open_conversation(self.account, {'kind': 'note'})['conversationId']
        message = self.messages(cid)[0]
        self.now += 2 * 86400000
        self.assertTrue(self.message(message['messageId'])['canEdit'])
        op = self.mutation(message)
        self.outbox.cancel(self.account, op['operationId'])
        self.assertEqual(self.message(message['messageId'])['text'], 'Notatka')
        self.assertIsNone(self.outbox.next(self.account))



class InteractionBridgeTests(unittest.TestCase):
    setUp = BridgeHistoryTests.setUp
    tearDown = BridgeHistoryTests.tearDown
    start = BridgeHistoryTests.start
    request = BridgeHistoryTests.request

    def test_actual_queue_routes_edit_and_reaction_methods_and_survives_restart(self):
        stamp = int(time.time() * 1000) - 10000
        client = self.start(receiveEvents=[event('sent-sync', timestamp=stamp, body='Pierwsza')], interactionTimestamp=stamp + 1000)
        client.state('ready')
        cid = self.request(client, 'conversations.page')['items'][0]['conversationId']
        mid = self.request(client, 'messages.page', {'conversationId': cid})['items'][0]['messageId']
        for method, extra in [('message.edit', {'text': 'Zmieniona'}), ('message.react', {'emoji': '👩‍💻'})]:
            value = self.request(client, 'message.get', {'messageId': mid})
            op = self.request(client, method, {'conversationId': cid, 'messageId': mid, 'versionTimestampMs': value['versionTimestampMs'], **extra})
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                result = self.request(client, 'operation.status', {'operationId': op['operationId']})
                if result['state'] == 'sent': break
                time.sleep(.02)
            self.assertEqual(result['state'], 'sent')
        value = self.request(client, 'message.get', {'messageId': mid})
        self.assertEqual(value['text'], 'Zmieniona')
        self.assertEqual(value['reactions'][0]['emoji'], '👩‍💻')
        client.close()
        records = list(map(json.loads, self.record.read_text().splitlines()))
        self.assertEqual(sum(r['kind'] == 'edit' for r in records), 1)
        self.assertEqual(sum(r['kind'] == 'reaction' for r in records), 1)


del HistoryTests, BridgeHistoryTests


class TypingTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        import asyncio
        from types import SimpleNamespace
        from unittest.mock import AsyncMock
        from signal_typing import Typing
        from test_signal_history import HistoryTests as Setup
        Setup.setUp(self)
        self.account_id = self.account
        self.account = SimpleNamespace(config={'typingIndicators': True})
        self.state = 'ready'
        self.transport = SimpleNamespace(request=AsyncMock(return_value={}))
        self.events = []
        self.event = lambda name, data: self.events.append((name, data))
        self.typing = Typing(self)
        self.cid = self.store.open_conversation(self.account_id, {'serviceId': PEER})['conversationId']

    async def asyncTearDown(self):
        from test_signal_history import HistoryTests as Setup
        self.typing.clear()
        Setup.tearDown(self)

    committed = lambda self, *_: None

    async def test_rate_limit_expiry_stop_and_disabled_preference(self):
        import asyncio
        params = {'accountId': self.account_id, 'conversationId': self.cid, 'active': True}
        for _ in range(20): await self.typing.set(params)
        self.assertEqual(self.transport.request.await_count, 1)
        self.assertFalse(self.transport.request.call_args.args[1]['stop'])
        now = asyncio.get_running_loop().time()
        self.typing.outgoing[self.cid] = (now - 9, now - 1)
        self.typing.expire()
        await asyncio.sleep(.02)
        self.assertEqual(self.transport.request.await_count, 2)
        self.assertTrue(self.transport.request.call_args.args[1]['stop'])
        self.assertFalse(self.typing.outgoing)
        self.assertIsNone(self.typing.timer)
        self.account.config['typingIndicators'] = False
        await self.typing.set(params)
        self.assertEqual(self.transport.request.await_count, 2)

    async def test_incoming_timeout_duplicates_stop_order_no_history_and_disconnect(self):
        import asyncio
        self.typing.receive(typing())
        self.assertEqual(self.events[-1][1]['authors'], ['aci:' + PEER])
        count = len(self.events)
        self.typing.receive(typing())
        self.assertEqual(len(self.events), count)
        self.typing.receive(typing(T + 2, False))
        self.typing.receive(typing(T + 1))
        self.assertEqual(self.events[-1][1]['authors'], [])
        self.typing.receive(typing(T + 3))
        self.typing.incoming[(self.cid, 'aci:' + PEER)] = (T + 3, asyncio.get_running_loop().time() - 1, True)
        self.typing.expire()
        self.assertEqual(self.events[-1][1]['authors'], [])
        self.assertEqual(self.store.db.execute('SELECT COUNT(*) FROM messages').fetchone()[0], 0)
        self.typing.receive(typing(T + 4))
        self.typing.clear()
        self.assertFalse(self.typing.incoming)
        self.assertIsNone(self.typing.timer)
