"""S10 actual bridge, private SQLite and explicit synthetic JSON-RPC peer."""
import copy
import json
from pathlib import Path
import time
import unittest
import uuid

import test_signal_history as history
from signal_directory import normalize

OWN, PEER, OTHER, GROUP = history.OWN, history.PEER, history.OTHER, history.GROUP
CREATED = 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE='


def group(**changes):
    return dict({'id': GROUP, 'name': 'Zespół 🐈', 'description': 'Opis', 'isMember': True, 'isBlocked': False,
        'isTerminated': False, 'messageExpirationTime': 0, 'members': [{'uuid': OWN, 'isAdmin': True}, {'uuid': PEER, 'isAdmin': False}],
        'admins': [{'uuid': OWN}], 'pendingMembers': [], 'requestingMembers': [], 'banned': [],
        'permissionAddMember': 'ONLY_ADMINS', 'permissionEditDetails': 'ONLY_ADMINS', 'permissionSendMessage': 'EVERY_MEMBER'}, **changes)


class GroupTests(unittest.TestCase):
    setUp = history.BridgeHistoryTests.setUp
    tearDown = history.BridgeHistoryTests.tearDown
    start = history.BridgeHistoryTests.start
    request = history.BridgeHistoryTests.request
    operation = history.BridgeHistoryTests.operation

    def ready(self, **scenario):
        client = self.start(**dict({'receiveEvents': [], 'groups': [group()]}, **scenario))
        self.account = client.state('ready')['data']['accountId']
        return client

    def call(self, client, method, **params):
        return self.request(client, method, dict(accountId=self.account, **params))

    def denied(self, client, method, code, **params):
        self.count += 1
        client.send(str(self.count), method, dict(accountId=self.account, **params))
        self.assertEqual(client.reply(str(self.count))['error']['code'], code)

    def records(self, kind):
        return [v for v in map(json.loads, self.record.read_text().splitlines()) if v['kind'] == kind]

    def mutate(self, client, action, **params):
        return self.call(client, 'group.update', operationId=str(uuid.uuid4()), groupId=GROUP, action=action, **params)

    def test_create_confirmed_result_reuses_operation_and_opens_actual_group(self):
        client = self.ready()
        op = str(uuid.uuid4())
        params = dict(operationId=op, name='Nowa 🐈', members=['aci:' + PEER])
        result = self.call(client, 'group.create', **params)
        self.assertEqual(result['state'], 'succeeded')
        self.assertEqual(result['target'], CREATED)
        self.assertEqual(self.call(client, 'conversation.get', conversationId=result['conversationId'])['title'], 'Nowa 🐈')
        self.assertEqual(self.call(client, 'group.create', **params), result)
        self.assertEqual(len(self.records('updateGroup')), 1)
        self.assertNotIn('groupId', self.records('updateGroup')[0]['params'])
        self.assertFalse(self.records('send'))
        self.denied(client, 'group.create', 'operation_conflict', **dict(params, name='Inna'))

    def test_unknown_create_restart_reconciles_candidates_without_second_create(self):
        directory = self.base / 'directory.json'
        client = self.ready(groupCrash=True, directoryFile=str(directory))
        op = str(uuid.uuid4())
        client.send('create-crash', 'group.create', {'accountId': self.account, 'operationId': op, 'name': 'Niepewna', 'members': ['aci:' + PEER]})
        client.state('ready', seconds=12)
        result = self.call(client, 'group.operations')['items'][0]
        self.assertEqual(result['state'], 'unknown')
        self.denied(client, 'group.create', 'operation_pending', operationId=str(uuid.uuid4()), name='Druga', members=['aci:' + PEER])
        candidate = self.call(client, 'group.reconcile', operationId=op)
        self.assertEqual(candidate['candidates'], [CREATED])
        self.assertEqual(candidate['state'], 'unknown')
        self.assertEqual(len(self.records('updateGroup')), 1)
        self.denied(client, 'group.reconcile', 'confirmation_required', operationId=op, groupId=CREATED)
        chosen = self.call(client, 'group.reconcile', operationId=op, groupId=CREATED, confirm='use-existing-group')
        self.assertEqual(chosen['state'], 'reconciled')
        self.assertTrue(chosen['conversationId'])
        client.close()
        client = self.ready(directoryFile=str(directory))
        self.assertEqual(self.call(client, 'group.operations')['items'][0]['state'], 'reconciled')
        self.assertEqual(len(self.records('updateGroup')), 1)

    def test_cancelled_create_late_reply_settles_without_retry(self):
        client = self.ready(groupDelay=.5)
        op = str(uuid.uuid4())
        client.send('slow', 'group.create', {'accountId': self.account, 'operationId': op, 'name': 'Spóźniona', 'members': ['aci:' + PEER]})
        deadline = time.monotonic() + 4
        while not self.records('updateGroup') and time.monotonic() < deadline: time.sleep(.02)
        self.request(client, 'request.cancel', {'id': 'slow'})
        time.sleep(.7)
        result = self.call(client, 'group.operations')['items'][0]
        self.assertEqual(result['state'], 'succeeded')
        self.assertEqual(len(self.records('updateGroup')), 1)

    def test_roles_permissions_last_admin_and_confirmations(self):
        client = self.ready()
        self.denied(client, 'group.quit', 'confirmation_required', operationId=str(uuid.uuid4()), groupId=GROUP)
        self.denied(client, 'group.quit', 'last_admin', operationId=str(uuid.uuid4()), groupId=GROUP, confirm=GROUP)
        self.denied(client, 'group.update', 'confirmation_required', operationId=str(uuid.uuid4()), groupId=GROUP, action='remove', members=['aci:' + PEER])
        self.mutate(client, 'promote', members=['aci:' + PEER])
        self.assertTrue(next(m for m in self.call(client, 'group.get', groupId=GROUP)['members'] if m['serviceId'] == 'aci:' + PEER)['isAdmin'])
        self.mutate(client, 'demote', members=['aci:' + PEER], confirm=GROUP)
        self.mutate(client, 'permissions', addMember='every-member', editDetails='every-member', sendMessages='only-admins')
        self.assertEqual(self.call(client, 'group.get', groupId=GROUP)['permissionSendMessage'], 'ONLY_ADMINS')
        result = self.call(client, 'group.quit', operationId=str(uuid.uuid4()), groupId=GROUP, confirm=GROUP, admins=['aci:' + PEER])
        self.assertFalse(self.call(client, 'conversation.get', conversationId=result['conversationId'])['canSend'])

    def test_nonadmin_and_incomplete_directory_fail_closed(self):
        value = group(members=[{'uuid': OWN, 'isAdmin': False}, {'uuid': PEER, 'isAdmin': True}], admins=[{'uuid': PEER}])
        client = self.ready(groups=[value])
        for action, params in [('details', {'name': 'Brak praw'}), ('remove', {'members': ['aci:' + PEER], 'confirm': GROUP}), ('add', {'members': ['aci:' + OTHER]}), ('link', {'link': 'enabled'})]:
            self.denied(client, 'group.update', 'permission_denied', operationId=str(uuid.uuid4()), groupId=GROUP, action=action, **params)
        self.assertFalse(self.records('updateGroup'))
        del value['permissionEditDetails']
        projection = normalize([], [value], 'aci:' + OWN)['groups'][0]
        self.assertFalse(projection['canEdit']); self.assertFalse(projection['canAdmin'])

    def test_join_waiting_invitation_accept_decline_and_member_requests(self):
        client = self.ready(onlyRequested=True)
        result = self.call(client, 'group.join', operationId=str(uuid.uuid4()), uri='https://signal.group/#SYNTHETIC_LINK_1234567890')
        self.assertEqual(result['state'], 'requesting')
        self.assertEqual(self.call(client, 'conversation.get', conversationId=result['conversationId'])['requestState'], 'requesting')
        self.denied(client, 'group.join', 'invalid_group_link', operationId=str(uuid.uuid4()), uri='https://example.com/#evil')
        client.close()
        client = self.ready(groups=[group(isMember=False, members=[{'uuid': PEER, 'isAdmin': True}], admins=[{'uuid': PEER}], pendingMembers=[{'uuid': OWN}])])
        self.assertTrue(self.call(client, 'group.get', groupId=GROUP)['canAccept'])
        self.mutate(client, 'accept')
        self.assertEqual(self.call(client, 'group.get', groupId=GROUP)['membership'], 'member')
        client.close()
        client = self.ready(groups=[group(requestingMembers=[{'uuid': OTHER}])])
        self.mutate(client, 'approve', members=['aci:' + OTHER])
        self.assertIn('aci:' + OTHER, [m['serviceId'] for m in self.call(client, 'group.get', groupId=GROUP)['members']])

    def test_unknown_request_no_read_send_typing_until_accept_then_block(self):
        client = self.ready(receiveEvents=[history.event()], contacts=[{'uuid': OWN, 'number': '+12025550100', 'profileSharing': True, 'messageExpirationTime': 0},
            {'uuid': PEER, 'number': '+12025550101', 'profileSharing': False, 'messageExpirationTime': 0}])
        row = self.request(client, 'conversations.page')['items'][0]
        cid = row['conversationId']; self.assertEqual(row['requestState'], 'pending')
        mid = self.request(client, 'messages.page', {'conversationId': cid})['items'][0]['messageId']
        self.assertEqual(self.call(client, 'messages.read', conversationId=cid, messageIds=[mid])['messageIds'], [])
        self.denied(client, 'message.send', 'send_unavailable', conversationId=cid, text='Nie wolno')
        self.call(client, 'typing.set', conversationId=cid, active=True)
        self.assertFalse(self.records('receipt')); self.assertFalse(self.records('send')); self.assertFalse(self.records('typing'))
        self.assertTrue(self.call(client, 'conversation.accept', conversationId=cid)['canSend'])
        self.assertEqual(len(self.records('sendMessageRequestResponse')), 1)
        self.assertEqual(self.call(client, 'messages.read', conversationId=cid, messageIds=[mid])['messageIds'], [mid])
        self.call(client, 'conversation.block', conversationId=cid, blocked=True, confirm=cid)
        self.denied(client, 'message.send', 'send_unavailable', conversationId=cid, text='Zablokowane')
        self.assertFalse(self.call(client, 'conversation.block', conversationId=cid, blocked=False)['blocked'])

    def test_rename_number_profile_mute_and_hidden_keep_history_identity(self):
        directory = self.base / 'directory.json'
        client = self.ready(directoryFile=str(directory), receiveEvents=[history.event(group=GROUP)])
        cid = self.request(client, 'conversations.page')['items'][0]['conversationId']
        self.mutate(client, 'details', name='Nowa nazwa', description='Nowy opis')
        item = self.call(client, 'conversation.get', conversationId=cid)
        self.assertEqual(item['title'], 'Nowa nazwa')
        messages = self.call(client, 'messages.page', conversationId=cid)['items']
        self.assertEqual(sum(m['kind'] == 'system' for m in messages), 1)
        self.assertEqual(item['unreadCount'], 1)
        self.call(client, 'conversation.notifications', conversationId=cid, muted=True)
        self.call(client, 'conversation.preferences', conversationId=cid, hidden=True)
        updated = json.loads(directory.read_text())
        updated['contacts'][1].update(name='Zmiana kontaktu', number='+12025550199')
        directory.write_text(json.dumps(updated))
        self.call(client, 'directory.refresh'); self.call(client, 'directory.refresh')
        item = self.call(client, 'conversation.get', conversationId=cid)
        self.assertTrue(item['muted']); self.assertTrue(item['hidden']); self.assertEqual(item['unreadCount'], 1)
        self.assertEqual(len(self.request(client, 'conversations.page')['items']), 1)
        self.assertEqual(self.call(client, 'directory.profile', serviceId='aci:' + PEER)['number'], '+12025550199')

    def test_partial_create_preserves_real_group_id_and_avatar_is_private(self):
        client = self.ready(groupResults=[{'recipientAddress': {'uuid': PEER}, 'type': 'NETWORK_FAILURE'}])
        result = self.call(client, 'group.create', operationId=str(uuid.uuid4()), name='Częściowa', members=['aci:' + PEER], avatar=str(history.ROOT / 'tests/fixtures/signal/media/image.png'))
        self.assertEqual(result['state'], 'partial'); self.assertEqual(result['target'], CREATED)
        avatar = self.call(client, 'directory.avatar', groupId=CREATED)['avatar']
        self.assertTrue(avatar.startswith('file://' + self.env['XDG_DATA_HOME']))
        self.assertTrue(Path(avatar.removeprefix('file://')).exists())
        self.assertFalse(Path(self.records('updateGroup')[0]['params']['avatar']).exists())

    def test_phone_loss_terminated_and_blocked_groups_cannot_enqueue_or_read(self):
        for change in ({'isMember': False}, {'isTerminated': True}, {'isBlocked': True}):
            with self.subTest(change=change):
                client = self.ready(groups=[group(**change)], receiveEvents=[history.event(group=GROUP)])
                row = self.request(client, 'conversations.page')['items'][0]
                self.assertFalse(row['canSend']); self.assertFalse(row['canRead'])
                self.denied(client, 'message.send', 'send_unavailable', conversationId=row['conversationId'], text='Nie wysyłaj', draftContext='quickReply')
                self.denied(client, 'group.update', 'permission_denied', operationId=str(uuid.uuid4()), groupId=GROUP, action='details', name='Niedozwolone')
                client.close()
        self.assertFalse(self.records('send'))

    def test_profile_number_and_avatar_changes_do_not_replace_direct_conversation(self):
        directory = self.base / 'directory.json'
        contacts = [{'uuid': OWN, 'number': '+12025550100', 'profileSharing': True, 'messageExpirationTime': 0},
                    {'uuid': PEER, 'number': '+12025550101', 'profileSharing': True, 'name': 'Stara nazwa', 'messageExpirationTime': 0}]
        directory.write_text(json.dumps({'contacts': contacts, 'groups': []}))
        client = self.ready(directoryFile=str(directory), receiveEvents=[history.event()])
        cid = self.request(client, 'conversations.page')['items'][0]['conversationId']
        mid = self.call(client, 'messages.page', conversationId=cid)['items'][0]['messageId']
        contacts[1].update(number='+12025550199', name='Nowa nazwa', username='alice.42')
        directory.write_text(json.dumps({'contacts': contacts, 'groups': []}))
        self.call(client, 'directory.refresh')
        self.call(client, 'directory.avatar', serviceId='aci:' + PEER)
        row = self.call(client, 'recipient.resolve', query='+12025550199')
        self.assertEqual(row['conversationId'], cid); self.assertEqual(row['title'], 'Nowa nazwa')
        self.assertEqual(self.call(client, 'messages.page', conversationId=cid)['items'][0]['messageId'], mid)
        self.assertEqual(len(self.request(client, 'conversations.page')['items']), 1)


class GroupContentTests(unittest.TestCase):
    setUp = history.HistoryTests.setUp
    tearDown = history.HistoryTests.tearDown
    committed = history.HistoryTests.committed
    conversation = history.HistoryTests.conversation
    messages = history.HistoryTests.messages
    enqueue = history.HistoryTests.enqueue

    def test_group_media_quotes_mentions_reactions_edits_receipts_delete_and_expiry(self):
        import test_signal_interactions as interactions
        import test_signal_receipts as receipts
        import test_signal_retention as retention
        import signal_receipts
        stamp = interactions.T
        cid = self.conversation('group', GROUP)
        self.store.receive(self.account, history.event(group=GROUP, timestamp=stamp, body='Autor grupy'))
        original = self.messages(cid)[0]
        self.assertEqual(original['authorServiceId'], 'aci:' + PEER)
        self.store.receive(self.account, interactions.edit(group=GROUP))
        self.store.receive(self.account, interactions.reaction(group=GROUP, actor=OTHER))
        current = self.store.message(self.account, original['messageId'])
        self.assertEqual(current['text'], 'Poprawiona 🐈'); self.assertEqual(current['reactions'][0]['people'][0]['serviceId'], 'aci:' + OTHER)
        media = history.event('attachment', group=GROUP, timestamp=stamp + 3000)
        self.store.receive(self.account, media)
        self.assertTrue(any(m['attachments'] for m in self.messages(cid)))
        op = self.enqueue(cid, '@Alicja', quoteMessageId=original['messageId'], mentions=[{'serviceId': 'aci:' + PEER, 'start': 0, 'length': 7}])
        args, attempt = self.outbox.begin(self.account, op['operationId'])
        self.assertEqual(args['groupId'], [GROUP]); self.assertNotIn('recipient', args)
        self.assertEqual(args['mention'], ['0:7:' + PEER]); self.assertEqual(args['quoteAuthor'], PEER)
        result = history.send_result(stamp + 4000)
        result['results'].append({'recipientAddress': {'uuid': OTHER}, 'type': 'SUCCESS'})
        self.outbox.finish(self.account, op['operationId'], attempt, result)
        self.store.receive(self.account, receipts.receipt('read', [stamp + 4000], peer=PEER))
        sent = self.store.message(self.account, op['messageId'])
        self.assertEqual(sent['receiptSummary']['read'], 1); self.assertEqual(sent['receiptSummary']['total'], 2)
        self.store.receive(self.account, retention.deletion(stamp + 5000, target=stamp, group=GROUP))
        self.assertEqual(self.store.message(self.account, original['messageId'])['kind'], 'deleted')
        quote = self.store.message(self.account, op['messageId']).get('quote')
        self.assertTrue(quote['unavailable']); self.assertEqual(quote['text'], '')
        self.store.receive(self.account, retention.disappearing(stamp=stamp + 6000, group=GROUP, seconds=1))
        expiring = next(m for m in self.messages(cid) if m['sentTimestampMs'] == stamp + 6000)
        signal_receipts.mark_visible(self.store, self.account, {'conversationId': cid, 'messageIds': [expiring['messageId']]})
        self.now += 1001
        with self.store.transaction(): self.store.cleanup()
        self.assertEqual(self.store.message(self.account, expiring['messageId'])['kind'], 'expired')
        self.assertTrue(all(m['conversationId'] == cid for m in self.messages(cid)))
