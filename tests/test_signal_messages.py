"""S04 new-recipient resolution and scoped window data through the real bridge."""
import json
import unittest
import uuid

import test_signal_history as history


class MessagingTests(unittest.TestCase):
    setUp = history.BridgeHistoryTests.setUp
    tearDown = history.BridgeHistoryTests.tearDown
    start = history.BridgeHistoryTests.start
    request = history.BridgeHistoryTests.request
    operation = history.BridgeHistoryTests.operation

    def error(self, client, method, params, expected):
        self.count += 1
        client.send(str(self.count), method, params)
        self.assertEqual(client.reply(str(self.count))["error"]["code"], expected)

    def test_phone_and_username_resolve_to_one_empty_scoped_conversation_without_send(self):
        client = self.start(receiveEvents=[])
        account = client.state("ready")["data"]["accountId"]
        first = self.request(client, "recipient.resolve", {"accountId": account, "query": "+12025550101"})
        second = self.request(client, "recipient.resolve", {"accountId": account, "query": "alice.42"})
        self.assertEqual(first["conversationId"], second["conversationId"])
        page = self.request(client, "messages.page", {"accountId": account, "conversationId": first["conversationId"]})
        self.assertEqual(page["items"], [])
        self.assertNotIn("send", [v["kind"] for v in map(json.loads, self.record.read_text().splitlines())])
        self.error(client, "conversation.get", {"accountId": str(uuid.uuid4()), "conversationId": first["conversationId"]}, "account_mismatch")
        self.error(client, "conversation.get", {"accountId": account, "conversationId": str(uuid.uuid4())}, "not_found")
        self.request(client, "draft.set", {"accountId": account, "conversationId": first["conversationId"], "text": "hjkl 🐈", "expectedRevision": 0})
        operation = self.request(client, "message.send", {"accountId": account, "conversationId": first["conversationId"], "text": "hjkl 🐈", "draftRevision": 1})
        self.operation(client, operation["operationId"], "sent")
        self.assertEqual(self.request(client, "draft.get", {"conversationId": first["conversationId"]})["text"], "")

    def test_invalid_and_unknown_recipient_never_create_or_send(self):
        client = self.start(receiveEvents=[], resolved=[])
        account = client.state("ready")["data"]["accountId"]
        for query in ("", "+12", "$(touch /tmp/no)", "alice", "../other"):
            self.error(client, "recipient.resolve", {"accountId": account, "query": query}, "invalid_request" if not query else "invalid_recipient")
        self.error(client, "recipient.resolve", {"accountId": str(uuid.uuid4()), "query": "+12025550101"}, "account_mismatch")
        self.error(client, "recipient.resolve", {"accountId": account, "query": "alice.42"}, "recipient_unresolved")
        self.assertEqual(self.request(client, "conversations.page")["items"], [])
        self.assertNotIn("send", [v["kind"] for v in map(json.loads, self.record.read_text().splitlines())])

    def test_directory_names_unread_and_permissions_are_model_data(self):
        client = self.start(receiveEvents=[history.event()], contacts=[
            {"number": "+12025550100", "uuid": history.OWN, "messageExpirationTime": 0},
            {"number": "+12025550101", "uuid": history.PEER, "name": "Alicja", "isBlocked": True, "messageExpirationTime": 0}])
        account = client.state("ready")["data"]["accountId"]
        row = self.request(client, "conversations.page")["items"][0]
        self.assertEqual(row["title"], "Alicja")
        self.assertEqual(row["unreadCount"], 1)
        self.assertFalse(row["canSend"])
        self.error(client, "message.send", {"accountId": account, "conversationId": row["conversationId"], "text": "blocked"}, "send_unavailable")
        # Reading pages/opening a route does not mark anything read before S06.
        self.request(client, "messages.page", {"conversationId": row["conversationId"]})
        self.assertEqual(self.request(client, "conversation.get", {"conversationId": row["conversationId"]})["unreadCount"], 1)

    def test_admin_only_group_and_disabled_account_block_send(self):
        client = self.start(receiveEvents=[history.event(group=history.GROUP)], groups=[
            {"id": history.GROUP, "name": "Projekt", "messageExpirationTime": 0, "isMember": True,
             "permissionSendMessage": "ONLY_ADMINS", "admins": [{"uuid": history.PEER}]}])
        client.state("ready")
        row = self.request(client, "conversations.page")["items"][0]
        self.assertEqual(row["title"], "Projekt")
        self.assertFalse(row["canSend"])
        self.error(client, "message.send", {"conversationId": row["conversationId"], "text": "blocked"}, "send_unavailable")
        self.request(client, "account.configure", {"enabled": False})
        client.state("disabled")
        self.error(client, "message.send", {"conversationId": row["conversationId"], "text": "blocked"}, "account_unlinked")
        self.assertNotIn("send", [v["kind"] for v in map(json.loads, self.record.read_text().splitlines())])
