"""S06: real private SQLite/bridge, synthetic protocol events, no phone."""
import copy
from contextlib import closing
import json
import sqlite3
import time
import unittest

from test_signal_history import HistoryTests, BridgeHistoryTests, event, send_result, EVENTS, OWN, PEER, OTHER, GROUP
from signal_events import normalize
from signal_store import Store
from signal_transport import Failure
import signal_receipts as reads


def receipt(kind, timestamps, peer=PEER, when=1790000300000):
    wire = copy.deepcopy(EVENTS["delivery-receipt"])
    env = wire["params"]["result"]["envelope"]
    env["sourceUuid"] = peer
    env["receiptMessage"] = {"when": when, "isDelivery": kind == "delivery", "isRead": kind == "read",
                             "isViewed": kind == "viewed", "timestamps": timestamps}
    return wire


def read_sync(timestamps, author=PEER):
    wire = copy.deepcopy(EVENTS["read-sync"])
    wire["params"]["result"]["envelope"]["syncMessage"]["readMessages"] = [
        {"senderUuid": author, "timestamp": t} for t in timestamps]
    return wire


class ReceiptTests(unittest.TestCase):
    setUp = HistoryTests.setUp
    tearDown = HistoryTests.tearDown
    reopen = HistoryTests.reopen
    conversation = HistoryTests.conversation
    messages = HistoryTests.messages
    committed = HistoryTests.committed
    enqueue = HistoryTests.enqueue

    def sent(self, timestamp=1790000002000, cid=None, peers=(PEER,), kinds=None):
        operation = self.enqueue(cid or self.conversation())
        _, attempt = self.outbox.begin(self.account, operation["operationId"])
        result = send_result(timestamp)
        result["results"] = [{"recipientAddress": {"uuid": peer}, "type": (kinds or {}).get(peer, "SUCCESS")} for peer in peers]
        self.outbox.finish(self.account, operation["operationId"], attempt, result)
        return operation["messageId"]

    def message(self, mid):
        return self.store.message(self.account, mid)

    def test_monotonic_delivery_read_viewed_duplicate_and_many_timestamps(self):
        ids = [self.sent(t) for t in (1790000002000, 1790000002001)]
        for kind, status in (("delivery", "delivered"), ("read", "read"), ("viewed", "viewed")):
            wire = receipt(kind, [1790000002000, 1790000002001])
            self.store.receive(self.account, wire)
            self.assertEqual([self.message(mid)["status"] for mid in ids], [status, status])
            self.changes.clear()
            self.store.receive(self.account, wire)
            self.assertEqual(self.changes, [])
        self.store.receive(self.account, receipt("delivery", [1790000002000], when=1790000400000))
        self.reopen()
        self.assertEqual(self.message(ids[0])["status"], "viewed")
        self.assertEqual(self.message(ids[0])["receiptSummary"], {"total": 1, "delivered": 1, "read": 1, "viewed": 1})

    def test_receipt_before_message_and_before_send_result_reconciles_exact_key(self):
        t = 1790000002000
        operation = self.enqueue(self.conversation())
        _, attempt = self.outbox.begin(self.account, operation["operationId"])
        self.store.receive(self.account, receipt("read", [t]))
        self.assertEqual(self.message(operation["messageId"])["status"], "sending")
        self.store.receive(self.account, event("sent-sync", timestamp=t))
        synced = next(m for m in self.messages(self.conversation()) if m["origin"] == "phone")
        self.assertEqual(synced["status"], "read")
        self.outbox.finish(self.account, operation["operationId"], attempt, send_result(t))
        self.assertEqual(len(self.messages(self.conversation())), 1)
        self.assertEqual(self.message(operation["messageId"])["status"], "read")
        self.assertEqual(self.outbox.status(self.account, operation["operationId"])["state"], "sent")

    def test_group_partial_per_recipient_and_foreign_actor(self):
        t = 1790000002000
        mid = self.sent(t, self.conversation("group", GROUP), (PEER, OTHER))
        self.store.receive(self.account, receipt("read", [t], PEER))
        value = self.message(mid)
        self.assertEqual(value["status"], "sent")
        self.assertEqual(value["receiptSummary"], {"total": 2, "delivered": 1, "read": 1, "viewed": 0})
        self.store.receive(self.account, receipt("viewed", [t], OWN))
        self.assertEqual(self.message(mid)["receiptSummary"], value["receiptSummary"])
        self.store.receive(self.account, receipt("delivery", [t], OTHER))
        self.assertEqual(self.message(mid)["status"], "delivered")
        self.store.receive(self.account, receipt("read", [t], OTHER))
        self.assertEqual(self.message(mid)["status"], "read")

    def test_group_partial_send_stays_failed_and_phone_group_has_unknown_audience(self):
        t = 1790000002000
        mid = self.sent(t, self.conversation("group", GROUP), (PEER, OTHER), {OTHER: "IDENTITY_FAILURE"})
        self.store.receive(self.account, receipt("read", [t]))
        self.assertEqual(self.message(mid)["status"], "failed")
        self.assertEqual(self.message(mid)["receiptSummary"]["read"], 1)
        self.store.receive(self.account, event("sent-sync", timestamp=t + 1, group=GROUP))
        self.store.receive(self.account, receipt("read", [t + 1]))
        phone = next(m for m in self.messages(self.conversation("group", GROUP)) if m["origin"] == "phone")
        self.assertEqual(phone["status"], "sent")
        self.assertIsNone(phone["receiptSummary"]["total"])

    def test_read_sync_is_own_read_not_external_receipt_and_does_not_touch_body(self):
        t = 1790000002000
        self.store.receive(self.account, event(timestamp=t, body="Syntetyczny tekst"))
        outgoing = self.sent(t)
        incoming = next(m for m in self.messages(self.conversation()) if m["direction"] == "incoming")
        self.store.receive(self.account, receipt("read", [t]))
        self.assertTrue(self.message(incoming["messageId"])["unread"])
        self.store.receive(self.account, read_sync([t]))
        self.assertFalse(self.message(incoming["messageId"])["unread"])
        self.assertEqual(self.message(incoming["messageId"])["text"], "Syntetyczny tekst")
        self.assertEqual(self.message(outgoing)["status"], "read")
        self.assertEqual(self.store.conversation_item(self.account, self.conversation())["unreadCount"], 0)
        self.assertIsNone(reads.next_batch(self.store, self.account))
        self.reopen()
        self.assertFalse(self.message(incoming["messageId"])["unread"])

    def test_phone_read_before_message_persists_and_suppresses_arrival(self):
        t = 1790000002000
        self.store.receive(self.account, read_sync([t]))
        self.reopen(); self.changes.clear()
        self.store.receive(self.account, event(timestamp=t))
        self.assertFalse(self.messages(self.conversation())[0]["unread"])
        self.assertFalse(any(name == "message.received" for name, _ in self.changes))
        self.store.receive(self.account, event(timestamp=t + 1))
        self.assertEqual(self.store.conversation_item(self.account, self.conversation())["unreadCount"], 1)
        self.store.receive(self.account, read_sync([t]))
        self.assertEqual(self.store.conversation_item(self.account, self.conversation())["unreadCount"], 1)

    def test_receipt_scope_account_direction_recipient_and_missing_aci(self):
        t = 1790000002000
        mid = self.sent(t)
        self.store.receive(self.account, receipt("read", [t], OTHER))
        self.store.receive(self.account, receipt("read", [t], "pni:" + PEER))
        wire = receipt("read", [t]); del wire["params"]["result"]["envelope"]["sourceUuid"]
        self.store.receive(self.account, wire)
        other_account = self.store.bind_account(OTHER, "+12025550102")
        wire = receipt("read", [t]); wire["params"]["result"]["account"] = "+12025550102"
        self.store.receive(other_account, wire)
        self.assertEqual(self.message(mid)["status"], "sent")
        self.store.receive(self.account, read_sync([t], OWN))
        self.assertEqual(self.message(mid)["status"], "sent")
        wire = read_sync([t]); wire["params"]["result"]["envelope"]["sourceUuid"] = OTHER
        with self.assertRaisesRegex(Failure, "invalid_event"):
            self.store.receive(self.account, wire)

    def test_visible_ids_atomic_scoped_idempotent_grouped_queue_survives_restart(self):
        cid = self.conversation()
        for t in range(1790000002000, 1790000002004):
            self.store.receive(self.account, event(timestamp=t))
        ids = [m["messageId"] for m in self.messages(cid)]
        result = reads.mark_visible(self.store, self.account, {"conversationId": cid, "messageIds": ids[1:3]})
        self.assertEqual(result["messageIds"], ids[1:3])
        self.assertEqual(self.store.conversation_item(self.account, cid)["unreadCount"], 2)
        self.assertEqual(reads.mark_visible(self.store, self.account, {"conversationId": cid, "messageIds": ids[1:3]}), {"messageIds": []})
        batch = reads.next_batch(self.store, self.account)
        self.assertEqual(batch, {"account": "+12025550100", "recipient": PEER, "type": "read", "targetTimestamp": [1790000002001, 1790000002002]})
        self.reopen()
        self.assertEqual(reads.next_batch(self.store, self.account), batch)
        other_cid = self.conversation(target=OTHER)
        with self.assertRaisesRegex(Failure, "not_found"):
            reads.mark_visible(self.store, self.account, {"conversationId": other_cid, "messageIds": ids})
        with self.assertRaisesRegex(Failure, "not_found"):
            reads.mark_visible(self.store, self.account, {"conversationId": cid, "messageIds": [ids[0], OWN]})
        self.assertTrue(self.message(ids[0])["unread"])

    def test_phone_cancels_queued_reads_and_disabled_external_receipts_empty_result_is_valid(self):
        self.store.receive(self.account, event(timestamp=1790000002000))
        cid = self.conversation(); mid = self.messages(cid)[0]["messageId"]
        reads.mark_visible(self.store, self.account, {"conversationId": cid, "messageIds": [mid]})
        batch = reads.next_batch(self.store, self.account)
        reads.batch_state(self.store, self.account, batch, "sending")
        reads.finish_batch(self.store, self.account, batch, {"timestamp": 1790000200000, "results": []}, None)
        self.assertEqual(self.store.db.execute("SELECT state FROM read_queue").fetchone()[0], "submitted")
        self.assertIsNone(reads.next_batch(self.store, self.account))
        self.store.receive(self.account, read_sync([1790000002000]))
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM read_queue").fetchone()[0], 0)

    def test_inflight_unknown_never_becomes_sent_by_reload_or_duplicate_visible_range(self):
        self.store.receive(self.account, event())
        cid = self.conversation(); mid = self.messages(cid)[0]["messageId"]
        reads.mark_visible(self.store, self.account, {"conversationId": cid, "messageIds": [mid]})
        batch = reads.next_batch(self.store, self.account)
        reads.batch_state(self.store, self.account, batch, "sending")
        self.reopen()
        self.assertEqual(self.store.db.execute("SELECT state FROM read_queue").fetchone()[0], "unknown")
        self.assertIsNone(reads.next_batch(self.store, self.account))
        self.assertFalse(self.message(mid)["unread"])

    def test_visible_group_reads_batch_by_author_and_bound_rpc_size(self):
        cid = self.conversation("group", GROUP)
        for i in range(103):
            self.store.receive(self.account, event(timestamp=1790000002000 + i, author=OTHER if i == 102 else PEER, group=GROUP))
        ids = [r[0] for r in self.store.db.execute("SELECT message_id FROM messages ORDER BY sent_ms")]
        for offset in (0, 100):
            reads.mark_visible(self.store, self.account, {"conversationId": cid, "messageIds": ids[offset:offset + 100]})
        for peer, count in ((PEER, 100), (PEER, 2), (OTHER, 1)):
            batch = reads.next_batch(self.store, self.account)
            self.assertEqual(batch["recipient"], peer)
            self.assertEqual(len(batch["targetTimestamp"]), count)
            reads.finish_batch(self.store, self.account, batch, {"timestamp": self.now, "results": []}, None)
        self.assertIsNone(reads.next_batch(self.store, self.account))

    def test_invalid_receipt_flags_and_wrong_submission_result_never_claim_success(self):
        wire = receipt("delivery", [1790000002000])
        wire["params"]["result"]["envelope"]["receiptMessage"]["isDelivery"] = False
        with self.assertRaisesRegex(Failure, "invalid_event"):
            self.store.receive(self.account, wire)
        self.store.receive(self.account, event())
        cid = self.conversation(); mid = self.messages(cid)[0]["messageId"]
        reads.mark_visible(self.store, self.account, {"conversationId": cid, "messageIds": [mid]})
        batch = reads.next_batch(self.store, self.account)
        reads.finish_batch(self.store, self.account, batch, send_result(recipient=OTHER), None)
        self.assertEqual(self.store.db.execute("SELECT state FROM read_queue").fetchone()[0], "unknown")

    def test_number_only_pending_request_does_not_read_or_mark_aci_copy(self):
        wire = event(); del wire["params"]["result"]["envelope"]["sourceUuid"]
        self.store.receive(self.account, wire)
        cid = self.store.page(self.account, {})["items"][0]["conversationId"]
        mid = self.messages(cid)[0]["messageId"]
        reads.mark_visible(self.store, self.account, {"conversationId": cid, "messageIds": [mid]})
        self.assertTrue(self.message(mid)["unread"])
        self.assertIsNone(reads.next_batch(self.store, self.account))
        self.store.receive(self.account, event())
        self.assertTrue(self.messages(self.conversation())[0]["unread"])

    def test_unmatched_metadata_expires_but_matched_receipts_and_markers_persist(self):
        self.store.receive(self.account, receipt("read", [1790000002000, 1790000002001]))
        mid = self.sent()
        self.store.receive(self.account, read_sync([1790000002002, 1790000002003]))
        self.store.receive(self.account, event(timestamp=1790000002002))
        self.now += 8 * 86400000
        self.reopen()
        self.assertEqual(self.message(mid)["status"], "read")
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM receipt_reports").fetchone()[0], 1)
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM read_markers").fetchone()[0], 1)

    def test_schema_v2_migrates_pending_reads_receipts_and_outbox_recipients(self):
        mid = self.sent()
        self.store.receive(self.account, event(timestamp=1790000003000))
        self.store.close(); self.store = None
        db = sqlite3.connect(self.lease.data / "history.sqlite3")
        for table in ("directory_operations", "directory_avatars", "conversation_preferences", "version_recipients", "interaction_outbox", "message_reactions", "message_versions", "message_metadata", "media_cli_gc", "draft_attachments", "media_files", "read_queue", "read_markers", "receipt_reports", "message_recipients"):
            db.execute("DROP TABLE " + table)
        db.execute("DROP TRIGGER attachment_cli_gc")
        db.execute("ALTER TABLE drafts DROP COLUMN composition")
        db.execute("DROP INDEX messages_unread")
        db.execute("DROP INDEX messages_receipt_target")
        db.execute("ALTER TABLE messages DROP COLUMN read_at_ms")
        for column in ("expiration_seconds", "expiration_start_ms", "hidden_local"):
            db.execute("ALTER TABLE messages DROP COLUMN " + column)
        for kind, t in (("read", 1790000002000), ("read_sync", 1790000003000)):
            db.execute("INSERT INTO pending_events VALUES(?,?,NULL,?,?,?,?,?)", (kind, self.account, kind, "aci:" + PEER, t, self.now, self.now + reads.TTL))
        db.execute("PRAGMA user_version=2"); db.commit(); db.close()
        self.store = Store(self.lease, self.committed, lambda: self.now)
        self.assertEqual(self.message(mid)["status"], "read")
        self.assertEqual(self.store.conversation_item(self.account, self.conversation())["unreadCount"], 0)
        self.assertEqual(self.store.db.execute("PRAGMA user_version").fetchone()[0], 7)


class ReceiptBridgeTests(unittest.TestCase):
    setUp = BridgeHistoryTests.setUp
    tearDown = BridgeHistoryTests.tearDown
    start = BridgeHistoryTests.start
    request = BridgeHistoryTests.request

    def test_read_batch_rpc_both_privacy_modes_restart_and_no_send(self):
        for privacy in (True, False):
            with self.subTest(externalReadReceipts=privacy):
                client = self.start(readReceipts=privacy, receiveEvents=[event(timestamp=t) for t in (1790000002000, 1790000002001)])
                client.state("ready")
                cid = self.request(client, "conversations.page")["items"][0]["conversationId"]
                items = self.request(client, "messages.page", {"conversationId": cid})["items"]
                result = self.request(client, "messages.read", {"conversationId": cid, "messageIds": [v["messageId"] for v in items]})
                if privacy:
                    self.assertEqual(len(result["messageIds"]), 2)
                dbpath = self.base / "data/putkin/signal/history.sqlite3"
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    with closing(sqlite3.connect(dbpath)) as db:
                        states = [r[0] for r in db.execute("SELECT state FROM read_queue")]
                    if states == ["submitted", "submitted"]:
                        break
                    time.sleep(.02)
                self.assertEqual(states, ["submitted", "submitted"])
                self.assertEqual(self.request(client, "conversations.page")["items"][0]["unreadCount"], 0)
                self.assertEqual(self.request(client, "messages.read", {"conversationId": cid, "messageIds": [v["messageId"] for v in items]}), {"messageIds": []})
                client.close()
                records = list(map(json.loads, self.record.read_text().splitlines()))
                receipts = [r["params"] for r in records if r["kind"] == "receipt"]
                self.assertEqual(len(receipts), 1)
                self.assertEqual(receipts[0], {"account": "+12025550100", "recipient": PEER, "type": "read", "targetTimestamp": [1790000002000, 1790000002001]})
                self.assertFalse(any(r["kind"] == "send" for r in records))
                # Use fresh keys for privacy-off, keeping the same real store.
                if privacy:
                    with closing(sqlite3.connect(dbpath)) as db:
                        db.execute("DELETE FROM read_queue")
                        db.execute("UPDATE messages SET read_at_ms=NULL")
                        db.execute("DELETE FROM read_markers")
                        db.commit()
                    self.record.write_text("")

    def test_read_sync_with_window_absent_and_receipt_before_rpc(self):
        t = 1790000002000
        client = self.start(receiveEvents=[event(timestamp=t), read_sync([t])], beforeSendReply=[receipt("read", [t])])
        client.state("ready")
        conversation = self.request(client, "conversations.page")["items"][0]
        self.assertEqual(conversation["unreadCount"], 0)
        op = self.request(client, "message.send", {"conversationId": conversation["conversationId"], "text": "Syntetyczne"})
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            message = self.request(client, "message.get", {"messageId": op["messageId"]})
            if message["status"] == "read":
                break
            time.sleep(.02)
        self.assertEqual(message["status"], "read")
        records = list(map(json.loads, self.record.read_text().splitlines()))
        self.assertFalse(any(r["kind"] == "receipt" for r in records))


del HistoryTests, BridgeHistoryTests

if __name__ == "__main__":
    unittest.main()
