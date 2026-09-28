"""Conversation organization uses real private SQLite and the production bridge."""
import unittest

from test_signal_history import HistoryTests, event, PEER, OTHER
from test_signal_groups import GroupTests
from signal_directory import preferences, layout
from signal_replies import configure
from signal_transport import Failure


class ConversationStoreTests(unittest.TestCase):
    setUp = HistoryTests.setUp
    tearDown = HistoryTests.tearDown
    reopen = HistoryTests.reopen
    committed = HistoryTests.committed
    conversation = HistoryTests.conversation
    messages = HistoryTests.messages
    enqueue = HistoryTests.enqueue

    def prefs(self, cid, **values):
        return preferences(self.store, self.account, dict(conversationId=cid, **values))

    def test_archive_preserves_history_draft_and_survives_restart(self):
        cid = self.conversation()
        self.store.receive(self.account, event(body='Zachowana treść'))
        before = self.messages(cid)
        self.store.set_draft(self.account, dict(conversationId=cid, text='Szkic', expectedRevision=0))
        self.prefs(cid, archived=True)
        self.reopen()
        self.assertTrue(self.store.conversation_item(self.account, cid)['archived'])
        self.assertEqual(self.messages(cid), before)
        self.assertEqual(self.store.draft(self.account, cid)['text'], 'Szkic')
        self.assertFalse(self.prefs(cid, archived=False)['archived'])

    def test_only_new_message_restores_archive_and_muted_stays_archived(self):
        cid = self.conversation()
        incoming = event(body='Pierwsza')
        self.store.receive(self.account, incoming)
        self.prefs(cid, archived=True)
        self.store.receive(self.account, incoming)
        self.assertTrue(self.store.conversation_item(self.account, cid)['archived'])
        self.store.receive(self.account, event(timestamp=self.now, body='Nowa'))
        self.assertFalse(self.store.conversation_item(self.account, cid)['archived'])
        configure(self.store, self.account, dict(conversationId=cid, muted=True))
        self.prefs(cid, archived=True)
        self.store.receive(self.account, event(timestamp=self.now+1, body='Wyciszona'))
        self.assertTrue(self.store.conversation_item(self.account, cid)['archived'])
        self.enqueue(cid, 'Odpowiedź')
        self.assertFalse(self.store.conversation_item(self.account, cid)['archived'])

    def test_pin_unarchives_and_archiving_unpins(self):
        cid = self.conversation()
        self.prefs(cid, archived=True)
        pinned = self.prefs(cid, pinned=True)
        self.assertTrue(pinned['pinned'])
        self.assertFalse(pinned['archived'])
        self.reopen()
        self.assertTrue(self.store.conversation_item(self.account, cid)['pinned'])
        self.assertFalse(self.prefs(cid, archived=True)['pinned'])

    def test_manual_unread_does_not_revert_receipts(self):
        cid = self.conversation()
        self.store.receive(self.account, event())
        from signal_receipts import mark_visible
        mark_visible(self.store, self.account, dict(conversationId=cid, messageIds=[self.messages(cid)[0]['messageId']]))
        before = self.messages(cid)
        self.assertTrue(self.prefs(cid, markedUnread=True)['markedUnread'])
        self.assertEqual(self.messages(cid), before)
        self.reopen()
        self.assertTrue(self.store.conversation_item(self.account, cid)['markedUnread'])

    def test_layout_is_typed_persistent_and_scoped_to_account(self):
        self.assertEqual(layout(self.store, self.account, {}), {'cardsCollapsed': False})
        layout(self.store, self.account, {'cardsCollapsed': True})
        self.reopen()
        self.assertTrue(layout(self.store, self.account, {})['cardsCollapsed'])
        second = self.store.bind_account(OTHER, '+12025550109')
        self.assertFalse(layout(self.store, second, {})['cardsCollapsed'])
        with self.assertRaises(Failure): layout(self.store, self.account, {'cardsCollapsed': 'false'})
        self.assertTrue(layout(self.store, self.account, {})['cardsCollapsed'])

    def test_invalid_and_foreign_route_do_not_mutate_preferences(self):
        cid = self.conversation()
        for params in ({}, {'archived': 1}, {'hidden': 1, 'archived': True},
                       {'hidden': True, 'archived': 1}, {'hidden': True, 'archived': False},
                       {'archived': True, 'pinned': True}):
            with self.assertRaises(Failure): self.prefs(cid, **params)
        other = self.store.bind_account(OTHER, '+12025550109')
        with self.assertRaises(Failure): preferences(self.store, other, dict(conversationId=cid, archived=True))
        self.assertFalse(self.store.conversation_item(self.account, cid)['archived'])

    def test_v8_hidden_migrates_to_archive_without_loss(self):
        cid = self.conversation()
        self.prefs(cid, hidden=True)
        self.store.receive(self.account, event())
        self.prefs(cid, hidden=True)
        before = self.messages(cid)
        with self.store.transaction():
            self.store.db.execute('ALTER TABLE conversation_preferences DROP COLUMN pinned')
            self.store.db.execute('ALTER TABLE conversation_preferences DROP COLUMN marked_unread')
            self.store.db.execute('PRAGMA user_version=8')
        self.reopen()
        item = self.store.conversation_item(self.account, cid)
        self.assertTrue(item['archived'])
        self.assertFalse(item['pinned'])
        self.assertFalse(item['markedUnread'])
        self.assertEqual(self.messages(cid), before)
        self.assertEqual(self.store.db.execute('PRAGMA user_version').fetchone()[0], 9)


class ConversationBridgeTests(unittest.TestCase):
    setUp = GroupTests.setUp
    tearDown = GroupTests.tearDown
    start = GroupTests.start
    request = GroupTests.request
    ready = GroupTests.ready
    call = GroupTests.call
    denied = GroupTests.denied

    def test_archive_layout_and_read_through_production_transport(self):
        client = self.ready(receiveEvents=[event(timestamp=1790000000000+i, body=str(i)) for i in range(105)])
        cid = self.call(client, 'conversation.open', kind='direct', serviceId=PEER)['conversationId']
        self.call(client, 'conversation.accept', conversationId=cid)
        self.call(client, 'conversation.preferences', conversationId=cid, archived=True, markedUnread=True)
        self.call(client, 'messages.preferences', cardsCollapsed=True)
        item = self.call(client, 'conversation.get', conversationId=cid)
        self.assertTrue(item['archived'])
        first = self.call(client, 'conversation.read', conversationId=cid)
        self.assertEqual(len(first['messageIds']), 100)
        self.assertTrue(first['hasMore'])
        second = self.call(client, 'conversation.read', conversationId=cid, throughMessageId=first['throughMessageId'])
        self.assertEqual(len(second['messageIds']), 5)
        item = self.call(client, 'conversation.get', conversationId=cid)
        self.assertEqual(item['unreadCount'], 0)
        self.assertFalse(item['markedUnread'])
        self.assertTrue(item['archived'])
        self.assertTrue(self.call(client, 'messages.preferences')['cardsCollapsed'])


del HistoryTests, GroupTests
