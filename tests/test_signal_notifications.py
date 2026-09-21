"""S05 synthetic notifications and quick reply persistence on real SQLite."""
from contextlib import closing
import sqlite3
import unittest
from unittest.mock import patch
import uuid

from test_signal_history import HistoryTests, event, send_result, OWN, PEER, OTHER, GROUP
from signal_store import Store
from signal_transport import Failure
import signal_replies


class NotificationTests(unittest.TestCase):
    setUp = HistoryTests.setUp
    tearDown = HistoryTests.tearDown
    reopen = HistoryTests.reopen
    conversation = HistoryTests.conversation
    messages = HistoryTests.messages
    committed = HistoryTests.committed
    enqueue = HistoryTests.enqueue

    def reply(self, cid, value="hjkl\nZażółć 🐈"):
        return signal_replies.set_draft(self.store, self.account, {"conversationId": cid, "text": value, "expectedRevision": 0})

    def send_reply(self, cid, draft, **extra):
        return self.enqueue(cid, draft["text"], draftContext="quickReply", draftRevision=draft["revision"],
                            operationId=extra.pop("operationId", str(uuid.uuid4())), **extra)

    def test_new_incoming_only_after_commit_without_duplicate_or_technical_toasts(self):
        wire = event()
        self.store.receive(self.account, wire)
        self.store.receive(self.account, wire)
        self.store.receive(self.account, event("sent-sync"))
        for name in ("delivery", "read", "reaction", "typing"):
            from test_signal_history import EVENTS
            if name in EVENTS:
                self.store.receive(self.account, event(name))
        received = [d for n, d in self.changes if n == "message.received"]
        self.assertEqual(len(received), 1)
        self.assertEqual(set(received[0]), {"accountId", "conversationId", "messageId"})
        with closing(sqlite3.connect(self.lease.data / "history.sqlite3")) as observer:
            self.assertEqual(observer.execute("SELECT direction FROM messages WHERE message_id=?", (received[0]["messageId"],)).fetchone()[0], "incoming")
        self.store.receive(self.account, event(body="same", author=OTHER, group=GROUP))
        self.assertEqual(len([d for n, d in self.changes if n == "message.received"]), 2)

    def test_reply_separate_from_composer_stable_operation_and_success(self):
        cid = self.conversation()
        self.store.set_draft(self.account, {"conversationId": cid, "text": "Szkic okna", "expectedRevision": 0})
        draft = self.reply(cid)
        operation = self.send_reply(cid, draft)
        # Same request is idempotent, even though the draft revision advanced.
        same = self.send_reply(cid, draft, operationId=operation["operationId"])
        self.assertEqual(same, operation)
        self.assertEqual(len(self.messages(cid)), 1)
        self.assertEqual(self.store.draft(self.account, cid)["text"], "Szkic okna")
        self.assertEqual(signal_replies.draft(self.store, self.account, cid)["text"], draft["text"])
        self.assertEqual(self.store.db.execute("SELECT body FROM reply_drafts").fetchone()[0], "")
        self.reopen()  # Lost enqueue response: recover the already committed UUID.
        self.assertEqual(signal_replies.draft(self.store, self.account, cid)["operationId"], operation["operationId"])
        _, attempt = self.outbox.begin(self.account, operation["operationId"])
        self.outbox.finish(self.account, operation["operationId"], attempt, send_result())
        current = signal_replies.draft(self.store, self.account, cid)
        self.assertEqual(current["state"], "sent")
        self.assertEqual(current["text"], "")
        signal_replies.set_draft(self.store, self.account, {"conversationId": cid, "text": "Następna", "expectedRevision": current["revision"]})
        self.assertIsNone(signal_replies.draft(self.store, self.account, cid)["operationId"])

    def test_unknown_blocks_new_intent_and_retention_cleans_every_reply_copy(self):
        cid = self.conversation()
        draft = self.reply(cid)
        operation = self.send_reply(cid, draft)
        self.outbox.begin(self.account, operation["operationId"])
        self.reopen()
        current = signal_replies.draft(self.store, self.account, cid)
        self.assertEqual(current["state"], "unknown")
        self.assertEqual(current["text"], draft["text"])
        self.assertFalse(current["safeRetry"])
        with self.assertRaises(Failure):
            self.outbox.retry(self.account, operation["operationId"])
        with self.assertRaisesRegex(Failure, "operation_in_progress"):
            self.send_reply(cid, current)
        self.assertEqual(len(self.messages(cid)), 1)  # failed enqueue rolled back
        self.now += 2 * 86400000
        with self.store.transaction():
            self.store.cleanup()
        self.assertEqual(signal_replies.draft(self.store, self.account, cid)["text"], "")
        self.assertFalse(signal_replies.draft(self.store, self.account, cid)["safeRetry"])

    def test_definite_failure_retries_existing_operation_and_keeps_text(self):
        cid = self.conversation()
        draft = self.reply(cid)
        operation = self.send_reply(cid, draft)
        _, attempt = self.outbox.begin(self.account, operation["operationId"])
        self.outbox.finish(self.account, operation["operationId"], attempt, send_result(kind="IDENTITY_FAILURE"))
        current = signal_replies.draft(self.store, self.account, cid)
        self.assertEqual(current["text"], draft["text"])
        self.assertTrue(current["safeRetry"])
        self.outbox.retry(self.account, operation["operationId"])
        self.assertEqual(len(self.messages(cid)), 1)
        self.assertEqual(signal_replies.draft(self.store, self.account, cid)["operationId"], operation["operationId"])

    def test_cas_account_scope_and_mute_are_persistent(self):
        cid = self.conversation()
        draft = self.reply(cid)
        with self.assertRaisesRegex(Failure, "draft_conflict"):
            self.reply(cid, "stale")
        account2 = self.store.bind_account(OTHER, "+12025550102")
        with self.assertRaisesRegex(Failure, "not_found"):
            signal_replies.draft(self.store, account2, cid)
        self.assertFalse(self.store.conversation_item(self.account, cid)["muted"])
        signal_replies.configure(self.store, self.account, {"conversationId": cid, "muted": True})
        self.reopen()
        self.assertTrue(self.store.conversation_item(self.account, cid)["muted"])
        self.assertEqual(signal_replies.draft(self.store, self.account, cid), draft)
        with self.assertRaises(Failure):
            signal_replies.configure(self.store, self.account, {"conversationId": cid, "muted": "false"})

    def test_migration_v1_preserves_history_and_rolls_back_on_failure(self):
        self.store.receive(self.account, event())
        cid = self.conversation()
        mid = self.messages(cid)[0]["messageId"]
        self.store.close(); self.store = None
        path = self.lease.data / "history.sqlite3"
        with closing(sqlite3.connect(path)) as db:
            for table in ("directory_operations", "directory_avatars", "conversation_preferences", "version_recipients", "interaction_outbox", "message_reactions", "message_versions", "message_metadata", "media_cli_gc", "draft_attachments", "media_files", "read_queue", "read_markers", "receipt_reports", "message_recipients"):
                db.execute("DROP TABLE " + table)
            db.execute("DROP TRIGGER attachment_cli_gc")
            db.execute("ALTER TABLE drafts DROP COLUMN composition")
            db.execute("DROP INDEX messages_unread")
            db.execute("DROP INDEX messages_receipt_target")
            db.execute("ALTER TABLE messages DROP COLUMN read_at_ms")
            for column in ("expiration_seconds", "expiration_start_ms", "hidden_local"):
                db.execute("ALTER TABLE messages DROP COLUMN " + column)
            db.execute("DROP TABLE reply_drafts")
            db.execute("DROP TABLE conversation_notifications")
            db.execute("PRAGMA user_version=1")
        connect = sqlite3.connect
        def deny(*args, **kwargs):
            db = connect(*args, **kwargs)
            db.set_authorizer(lambda action, name, *_: sqlite3.SQLITE_DENY if action == sqlite3.SQLITE_CREATE_TABLE and name == "conversation_notifications" else sqlite3.SQLITE_OK)
            return db
        with patch("signal_store.sqlite3.connect", deny):
            with self.assertRaisesRegex(Failure, "storage_error"):
                Store(self.lease)
        with closing(connect(path)) as db:
            self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 1)
            self.assertFalse(db.execute("SELECT 1 FROM sqlite_master WHERE name='reply_drafts'").fetchone())
        self.store = Store(self.lease)
        self.assertEqual(self.store.db.execute("PRAGMA user_version").fetchone()[0], 7)
        self.assertEqual(self.messages(cid)[0]["messageId"], mid)


# Reused fixture methods do not make the S02 class part of this test module.
del HistoryTests
