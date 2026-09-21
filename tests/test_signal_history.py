"""S02 synthetic history/outbox tests, actual private SQLite files and pipes."""
import copy
from contextlib import closing
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services"))
from signal_events import normalize
from signal_outbox import Outbox
from signal_paths import StoreLease
from signal_store import Store
from signal_transport import Failure
from test_signal_lifecycle import Client, environment, gone

OWN = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
PEER = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
OTHER = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
GROUP = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
FIXTURE = json.loads((ROOT / "tests/fixtures/signal/v0.14.8/session.json").read_text())
EVENTS = {e["name"]: e["wire"] for e in FIXTURE["events"]}


def event(name="incoming", *, timestamp=None, body=None, author=None, group=None):
    value = copy.deepcopy(EVENTS[name])
    env = value["params"]["result"]["envelope"]
    data = env.get("dataMessage") or env.get("syncMessage", {}).get("sentMessage")
    if timestamp is not None:
        env["timestamp"] = data["timestamp"] = timestamp
    if body is not None:
        data["message"] = body
    if author is not None:
        env["sourceUuid"] = author
    if group is not None:
        data["groupInfo"] = {"groupId": group, "type": "DELIVER"}
    return value


def send_result(timestamp=1790000002000, kind="SUCCESS", recipient=PEER):
    return {"timestamp": timestamp, "results": [{"recipientAddress": {"uuid": recipient}, "type": kind}]}


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="pk-signal-history-")
        self.base = Path(self.tmp.name)
        self.env = environment(self.base)
        self.environment = patch.dict(os.environ, self.env)
        self.environment.start()
        self.old_umask = os.umask(0o077)
        self.lease = StoreLease()
        self.assertTrue(self.lease.acquire())
        self.changes = []
        self.now = 1790000100000
        self.store = Store(self.lease, self.committed, lambda: self.now)
        self.outbox = Outbox(self.store)
        self.account = self.store.bind_account(OWN, "+12025550100")
        # Earlier stages exercise already accepted synthetic conversations.
        with self.store.transaction():
            self.store.db.execute('INSERT INTO store_metadata VALUES(?,?)', ('directory:' + self.account, json.dumps({
                'contacts': [{'serviceId': 'aci:' + PEER, 'profileSharing': True}, {'serviceId': 'aci:' + OTHER, 'profileSharing': True}],
                'groups': [{'groupId': GROUP, 'membership': 'member', 'isMember': True, 'canSend': True, 'canEdit': True, 'members': [{'serviceId': 'aci:' + PEER}]}]})))

    def committed(self, name, data):
        # An independent connection must already see the committed entity.
        if name == "message.changed":
            with closing(sqlite3.connect(self.lease.data / "history.sqlite3")) as observer:
                self.assertIsNotNone(observer.execute("SELECT 1 FROM messages WHERE message_id=?", (data["messageId"],)).fetchone())
        self.changes.append((name, data))

    def tearDown(self):
        if self.store:
            self.store.close()
        self.lease.close()
        os.umask(self.old_umask)
        self.environment.stop()
        self.tmp.cleanup()

    def reopen(self):
        self.store.close()
        self.store = Store(self.lease, self.committed, lambda: self.now)
        self.outbox = Outbox(self.store)

    def conversation(self, kind="direct", target=PEER, account=None):
        return self.store.open_conversation(account or self.account, {"kind": kind, "serviceId": target, "groupId": target})["conversationId"]

    def messages(self, cid, account=None):
        return self.store.page(account or self.account, {"conversationId": cid}, messages=True)["items"]

    def enqueue(self, cid, body="Odpowiedź z Putkina", **params):
        return self.outbox.enqueue(self.account, {"conversationId": cid, "text": body, **params})

    def test_phone_incoming_local_reply_and_restart_preserve_history_draft_and_outbox(self):
        self.store.receive(self.account, event())
        self.store.receive(self.account, event("sent-sync"))
        cid = self.conversation()
        op = self.enqueue(cid)
        args, attempt = self.outbox.begin(self.account, op["operationId"])
        self.assertEqual(args["recipient"], [PEER])
        self.outbox.finish(self.account, op["operationId"], attempt, send_result())
        self.store.set_draft(self.account, {"conversationId": cid, "text": "hjkl 🐈\nciąg dalszy", "expectedRevision": 0})
        self.reopen()
        messages = self.messages(cid)
        self.assertEqual(len(messages), 3)
        self.assertEqual([m["direction"] for m in messages], ["outgoing", "outgoing", "incoming"])
        self.assertEqual({m["origin"] for m in messages}, {"remote", "phone", "local"})
        self.assertEqual(self.store.draft(self.account, cid)["revision"], 1)
        self.assertEqual(self.outbox.status(self.account, op["operationId"])["state"], "sent")
        self.assertTrue(any(n == "message.changed" for n, _ in self.changes))
        self.assertEqual(self.store.db.execute("PRAGMA user_version").fetchone()[0], 7)
        self.assertEqual(self.store.db.execute("PRAGMA synchronous").fetchone()[0], 2)
        for suffix in ("", "-wal", "-shm"):
            self.assertEqual((self.lease.data / ("history.sqlite3" + suffix)).stat().st_mode & 0o777, 0o600)

    def test_duplicates_protocol_keys_do_not_merge_equal_text_authors_groups_accounts(self):
        first = event(body="identyczny tekst")
        for _ in range(3):
            self.store.receive(self.account, first)
        second = event(timestamp=1790000000001, body="identyczny tekst")
        self.store.receive(self.account, second)
        self.store.receive(self.account, event(body="identyczny tekst", author=OTHER))
        self.store.receive(self.account, event(body="identyczny tekst", group=GROUP))
        self.store.receive(self.account, event(body="identyczny tekst", author=OTHER, group=GROUP))
        other_group = "AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        self.store.receive(self.account, event(body="identyczny tekst", group=other_group))
        account2 = self.store.bind_account(OTHER, "+12025550102")
        copy2 = copy.deepcopy(first)
        copy2["params"]["result"]["account"] = "+12025550102"
        self.store.receive(account2, copy2)
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM messages").fetchone()[0], 7)
        self.assertEqual(len(self.messages(self.conversation())), 2)
        self.assertEqual(len(self.messages(self.conversation("group", GROUP))), 2)
        note = event("sent-sync")
        note["params"]["result"]["envelope"]["syncMessage"]["sentMessage"]["destinationUuid"] = OWN
        self.store.receive(self.account, note)
        self.assertEqual(len(self.messages(self.conversation("note"))), 1)

    def test_payload_conflict_and_source_device_are_not_silent_overwrites(self):
        self.store.receive(self.account, event(body="pierwsza"))
        same = event(body="pierwsza")
        same["params"]["result"]["envelope"]["sourceDevice"] = 2
        self.store.receive(self.account, same)
        self.assertFalse(self.messages(self.conversation())[0]["conflict"])
        self.store.receive(self.account, event(body="inna"))
        rows = self.messages(self.conversation())
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["text"], "pierwsza")
        self.assertTrue(rows[0]["conflict"])

    def test_sync_before_and_after_rpc_preserve_local_key(self):
        for before in (True, False):
            with self.subTest(before=before):
                timestamp = 1790000002000 + int(before)
                cid = self.conversation()
                op = self.enqueue(cid)
                _, attempt = self.outbox.begin(self.account, op["operationId"])
                sync = event("sent-sync", timestamp=timestamp, body="Odpowiedź z Putkina")
                if before:
                    self.store.receive(self.account, sync)
                self.outbox.finish(self.account, op["operationId"], attempt, send_result(timestamp))
                for _ in range(2):
                    self.store.receive(self.account, sync)
                matching = [m for m in self.messages(cid) if m["sentTimestampMs"] == timestamp]
                self.assertEqual([m["messageId"] for m in matching], [op["messageId"]])
                self.assertFalse(matching[0]["conflict"])

    def test_unknown_no_timestamp_never_guesses_by_text_and_retry_is_explicitly_rejected(self):
        cid = self.conversation()
        op = self.enqueue(cid)
        self.outbox.begin(self.account, op["operationId"])
        self.reopen()
        self.assertEqual(self.outbox.status(self.account, op["operationId"])["state"], "unknown")
        self.assertIsNone(self.outbox.next(self.account))
        self.store.receive(self.account, event("sent-sync", timestamp=self.now, body="Odpowiedź z Putkina"))
        self.assertEqual(len(self.messages(cid)), 2)  # Unproven local intent remains separate.
        with self.assertRaisesRegex(Failure, "retry_unsafe"):
            self.outbox.retry(self.account, op["operationId"])
        self.outbox.finish(self.account, op["operationId"], 1, send_result(self.now))
        self.assertEqual(len(self.messages(cid)), 1)
        self.assertEqual(self.outbox.status(self.account, op["operationId"])["state"], "sent")

    def test_per_recipient_partial_network_failure_and_safe_retry(self):
        cid = self.conversation("group", GROUP)
        op = self.enqueue(cid)
        _, attempt = self.outbox.begin(self.account, op["operationId"])
        result = send_result()
        result["results"] += send_result(kind="IDENTITY_FAILURE", recipient=OTHER)["results"]
        self.outbox.finish(self.account, op["operationId"], attempt, result)
        status = self.outbox.status(self.account, op["operationId"])
        self.assertEqual(status["state"], "failed")
        self.assertEqual(status["errorCode"], "partial_send")
        self.assertEqual(len(status["recipients"]), 2)
        self.assertFalse(status["safeRetry"])
        for kind, expected, retryable in (("NETWORK_FAILURE", "unknown", False), ("IDENTITY_FAILURE", "failed", True)):
            op = self.enqueue(self.conversation())
            _, attempt = self.outbox.begin(self.account, op["operationId"])
            self.outbox.finish(self.account, op["operationId"], attempt, send_result(kind=kind))
            self.assertEqual(self.outbox.status(self.account, op["operationId"])["state"], expected)
            self.assertEqual(self.outbox.status(self.account, op["operationId"])["safeRetry"], retryable)
        self.outbox.retry(self.account, op["operationId"])
        self.assertEqual(self.outbox.status(self.account, op["operationId"])["state"], "queued")
        _, attempt = self.outbox.begin(self.account, op["operationId"])
        self.assertEqual(attempt, 2)

    def test_missing_timestamp_wrong_recipient_and_rpc_error_are_unknown(self):
        for result in ({"timestamp": 123}, send_result(recipient=OTHER), {"results": []}):
            op = self.enqueue(self.conversation())
            _, attempt = self.outbox.begin(self.account, op["operationId"])
            self.outbox.finish(self.account, op["operationId"], attempt, result)
            self.assertEqual(self.outbox.status(self.account, op["operationId"])["state"], "unknown")
        op = self.enqueue(self.conversation())
        _, attempt = self.outbox.begin(self.account, op["operationId"])
        self.outbox.finish(self.account, op["operationId"], attempt, None, {"code": -3, "data": "PRIVATE"})
        self.assertEqual(self.outbox.status(self.account, op["operationId"])["state"], "unknown")
        self.assertNotIn("PRIVATE", " ".join(self.store.db.iterdump()))

    def test_queue_idempotence_draft_compare_and_swap_and_cancel(self):
        cid = self.conversation()
        draft = {"conversationId": cid, "text": "hej", "expectedRevision": 0}
        self.store.set_draft(self.account, draft)
        with self.assertRaisesRegex(Failure, "draft_conflict"):
            self.store.set_draft(self.account, draft)
        opid = str(uuid.uuid4())
        first = self.enqueue(cid, "hej", operationId=opid, draftRevision=1)
        self.assertEqual(self.store.draft(self.account, cid), {"conversationId": cid, "text": "", "revision": 2, "attachments": []})
        self.assertEqual(self.enqueue(cid, "hej", operationId=opid, draftRevision=1)["messageId"], first["messageId"])
        with self.assertRaisesRegex(Failure, "operation_conflict"):
            self.enqueue(cid, "co innego", operationId=opid)
        self.outbox.cancel(self.account, opid)
        self.assertIsNone(self.outbox.next(self.account))
        self.reopen()
        self.assertEqual(self.outbox.status(self.account, opid)["state"], "cancelled")

    def test_delete_and_edit_before_target_never_restore_content_and_pending_is_bounded(self):
        for kind in ("remote-delete", "edit"):
            self.store.receive(self.account, copy.deepcopy(EVENTS[kind]))
        self.store.receive(self.account, event())
        self.assertIsNone(self.messages(self.conversation())[0]["text"])
        self.reopen()
        self.store.receive(self.account, event())
        self.assertIsNone(self.messages(self.conversation())[0]["text"])
        for name in ("reaction", "read-sync", "read-receipt", "delivery-receipt"):
            self.store.receive(self.account, copy.deepcopy(EVENTS[name]))
        self.assertGreater(self.store.db.execute("SELECT COUNT(*) FROM receipt_reports WHERE expires_at_ms IS NOT NULL").fetchone()[0], 0)
        self.now += 8 * 86400 * 1000
        self.reopen()
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM pending_events").fetchone()[0], 0)

    def test_view_once_and_unknown_events_do_not_archive_payloads(self):
        secret = "SHOULD_NEVER_REACH_SQLITE"
        self.store.receive(self.account, event("view-once", body=secret))
        unknown = copy.deepcopy(EVENTS["unknown-future-event"])
        unknown["params"]["private"] = secret
        self.store.receive(self.account, unknown)
        self.assertNotIn(secret, " ".join(self.store.db.iterdump()))
        for suffix in ("", "-wal"):
            self.assertNotIn(secret.encode(), (self.lease.data / ("history.sqlite3" + suffix)).read_bytes())
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM attachments").fetchone()[0], 0)
        self.enqueue(self.conversation())
        self.store.receive(self.account, event("attachment"))
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM attachment_refs").fetchone()[0], 1)
        self.assertTrue(any(m["kind"] == "view_once_unsupported" for m in self.messages(self.conversation())))

    def test_pagination_ties_scopes_large_frames_and_safe_integer_timestamps(self):
        cid = self.conversation()
        body = "🐈" * 12000
        for i in range(15):
            self.store.receive(self.account, event(timestamp=1790000000000 + i, body=body))
        ids, cursor = [], None
        while True:
            page = self.store.page(self.account, {"conversationId": cid, "limit": 100, "before": cursor}, messages=True)
            self.assertLess(len(json.dumps(page, ensure_ascii=False).encode()), 600 * 1024)
            ids += [m["messageId"] for m in page["items"]]
            cursor = page["nextCursor"]
            if cursor is None:
                break
            with self.assertRaisesRegex(Failure, "invalid_cursor"):
                self.store.page(self.account, {"before": cursor})
        self.assertEqual(len(ids), 15)
        self.assertEqual(len(set(ids)), 15)
        for bad in (2**53, -1, True):
            with self.assertRaisesRegex(Failure, "invalid_event"):
                self.store.receive(self.account, event(timestamp=bad))
        # Several optimistic sends can share the same local millisecond.
        for _ in range(5):
            self.enqueue(cid, "tie")
        page = self.store.page(self.account, {"conversationId": cid, "limit": 2}, messages=True)
        next_page = self.store.page(self.account, {"conversationId": cid, "limit": 2, "before": page["nextCursor"]}, messages=True)
        self.assertFalse({m["messageId"] for m in page["items"]} & {m["messageId"] for m in next_page["items"]})

    def test_number_only_recipient_stays_unresolved_and_account_rebinding_is_by_aci(self):
        unresolved = event()
        del unresolved["params"]["result"]["envelope"]["sourceUuid"]
        self.store.receive(self.account, unresolved)
        self.store.receive(self.account, event())
        self.assertEqual(len(self.store.page(self.account, {})["items"]), 2)
        self.assertEqual(self.store.bind_account(OWN, "+12025550199"), self.account)
        other = self.store.bind_account(OTHER, "+12025550199")
        self.assertNotEqual(other, self.account)

    def test_invalid_event_diagnostic_contains_only_static_source_location(self):
        from signal_events import EventFailure
        wire = event(body="PRIVATE_BODY", author="PRIVATE_ID")
        with self.assertRaises(EventFailure) as caught:
            self.store.receive(self.account, wire)
        self.assertEqual(str(caught.exception), "invalid_event")
        self.assertRegex(caught.exception.location, r"^signal_events:[0-9]+$")
        wire = event()
        wire["params"]["result"]["account"] = "PRIVATE_ACCOUNT"
        with self.assertRaises(EventFailure) as caught:
            self.store.receive(self.account, wire)
        self.assertEqual(caught.exception.location, "account_binding")

    def test_full_disk_and_readonly_transaction_never_publish_uncommitted_message(self):
        cid = self.conversation()
        self.changes.clear()
        pages = self.store.db.execute("PRAGMA page_count").fetchone()[0]
        self.store.db.execute(f"PRAGMA max_page_count={pages}")
        with self.assertRaisesRegex(Failure, "storage_error"):
            self.enqueue(cid, "x" * 64000)
        self.assertEqual(self.changes, [])
        self.assertEqual(self.store.db.execute("SELECT COUNT(*) FROM messages").fetchone()[0], 0)
        self.reopen()
        self.changes.clear()
        self.store.db.execute("PRAGMA query_only=ON")
        with self.assertRaisesRegex(Failure, "storage_error"):
            self.store.receive(self.account, event())
        self.assertEqual(self.changes, [])

    def test_expired_outbox_cleanup_and_tombstone_after_restart(self):
        op = self.enqueue(self.conversation())
        failed = self.enqueue(self.conversation())
        _, attempt = self.outbox.begin(self.account, failed["operationId"])
        self.outbox.finish(self.account, failed["operationId"], attempt, send_result(kind="IDENTITY_FAILURE"))
        self.assertTrue(self.outbox.status(self.account, failed["operationId"])["safeRetry"])
        self.now += 2 * 86400 * 1000
        self.reopen()
        self.assertIsNone(self.outbox.next(self.account))
        self.assertIsNone(self.store.message(self.account, op["messageId"])["text"])
        self.assertFalse(self.outbox.status(self.account, failed["operationId"])["safeRetry"])
        with self.assertRaisesRegex(Failure, "retry_unsafe"):
            self.outbox.retry(self.account, op["operationId"])

    def test_redaction_clears_wal_and_checkpoint_failure_blocks_publication(self):
        marker = "SYNTHETIC_REDACTION_MARKER_928164"
        self.store.receive(self.account, event(body=marker))
        self.store.receive(self.account, copy.deepcopy(EVENTS["remote-delete"]))
        for suffix in ("", "-wal"):
            self.assertNotIn(marker.encode(), (self.lease.data / ("history.sqlite3" + suffix)).read_bytes())
        timestamp = 1790000009000
        self.store.receive(self.account, event(timestamp=timestamp, body=marker))
        cid = self.conversation()
        observer = sqlite3.connect(self.lease.data / "history.sqlite3")
        observer.execute("BEGIN")
        observer.execute("SELECT * FROM messages").fetchall()
        self.changes.clear()
        try:
            with self.assertRaisesRegex(Failure, "storage_error"):
                with self.store.transaction():
                    self.store.redact(self.account, cid, "aci:" + PEER, timestamp, "deleted")
            self.assertEqual(self.changes, [])
        finally:
            observer.close()
        self.reopen()
        self.assertIsNone(self.messages(self.conversation())[0]["text"])
        for suffix in ("", "-wal"):
            self.assertNotIn(marker.encode(), (self.lease.data / ("history.sqlite3" + suffix)).read_bytes())

    def test_schema_rollback_newer_version_corrupt_db_and_unsafe_companions(self):
        self.store.close()
        self.store = None
        path = self.lease.data / "history.sqlite3"
        with closing(sqlite3.connect(path)) as db:
            db.execute("PRAGMA user_version=999")
        before = path.read_bytes()
        with self.assertRaisesRegex(Failure, "unsupported_schema"):
            Store(self.lease)
        self.assertEqual(path.read_bytes(), before)
        path.write_bytes(b"not a database")
        with self.assertRaisesRegex(Failure, "storage_error"):
            Store(self.lease)
        path.unlink()
        connect = sqlite3.connect
        def broken_migration(*args, **kwargs):
            db = connect(*args, **kwargs)
            db.set_authorizer(lambda action, name, *_: sqlite3.SQLITE_DENY if action == sqlite3.SQLITE_CREATE_TABLE and name == "drafts" else sqlite3.SQLITE_OK)
            return db
        with patch("signal_store.sqlite3.connect", broken_migration):
            with self.assertRaisesRegex(Failure, "storage_error"):
                Store(self.lease)
        with closing(connect(path)) as db:
            self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 0)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table'").fetchone()[0], 0)
        victim = self.base / "victim"
        victim.write_text("unchanged")
        (self.lease.data / "history.sqlite3-wal").symlink_to(victim)
        with self.assertRaisesRegex(Failure, "storage_error"):
            Store(self.lease)
        self.assertEqual(victim.read_text(), "unchanged")

    def test_process_death_before_after_commit_and_after_sending_marker(self):
        for phase, expected in (("before", None), ("after", "queued"), ("sending", "unknown")):
            with self.subTest(phase=phase):
                base = self.base / phase
                base.mkdir(mode=0o700)
                env = environment(base)
                command = [sys.executable, "-B", str(ROOT / "tests/signal_store_crash.py"), phase]
                result = subprocess.run(command, env=env, capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 90, result.stderr.decode())
                with patch.dict(os.environ, env):
                    lease = StoreLease()
                    self.assertTrue(lease.acquire())
                    store = Store(lease)
                    try:
                        rows = store.db.execute("SELECT state FROM outbox").fetchall()
                        self.assertEqual([r[0] for r in rows], [] if expected is None else [expected])
                        self.assertEqual(store.db.execute("PRAGMA integrity_check").fetchone()[0], "ok")
                    finally:
                        store.close()
                        lease.close()


class BridgeHistoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="pk-signal-domain-")
        self.base = Path(self.tmp.name)
        self.env = environment(self.base)
        self.fixture = self.base / "fixture.json"
        self.record = self.base / "processes.jsonl"
        self.clients = []
        self.count = 0

    def start(self, command=None, **scenario):
        self.fixture.write_text(json.dumps({"format": 1, "synthetic": True, "record": str(self.record), **scenario}))
        client = Client(self.env, self.fixture, command=command)
        self.clients.append(client)
        return client

    def request(self, client, method, params=None):
        self.count += 1
        rid = str(self.count)
        client.send(rid, method, params)
        reply = client.reply(rid)
        self.assertNotIn("error", reply)
        return reply["result"]

    def operation(self, client, op, state, seconds=8):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            value = self.request(client, "operation.status", {"operationId": op})
            if value["state"] == state:
                return value
            time.sleep(.02)
        self.fail(f"Operation did not reach {state}: {value}")

    def tearDown(self):
        for client in self.clients:
            client.close()
        if self.record.exists():
            for line in self.record.read_text().splitlines():
                row = json.loads(line)
                if row["kind"] == "start":
                    self.assertTrue(gone(row["pid"]))
        self.tmp.cleanup()

    def test_end_to_end_receive_send_sync_pages_drafts_commit_and_restart(self):
        sync = event("sent-sync", timestamp=1790000002000, body="Odpowiedź z Putkina")
        client = self.start(beforeSendReply=[sync], afterSendReply=[sync])
        state = client.state("ready")
        cid = self.request(client, "conversations.page")["items"][0]["conversationId"]
        opid = str(uuid.uuid4())
        accepted = self.request(client, "message.send", {"conversationId": cid, "text": "Odpowiedź z Putkina", "operationId": opid})
        self.assertEqual(accepted["state"], "queued")
        self.operation(client, opid, "sent")
        self.request(client, "draft.set", {"conversationId": cid, "text": "szkic hjkl", "expectedRevision": 0})
        client.close()
        client = self.start()
        new_state = client.state("ready")
        self.assertEqual(state["data"]["accountId"], new_state["data"]["accountId"])
        self.assertNotEqual(state["generation"], new_state["generation"])
        page = self.request(client, "messages.page", {"conversationId": cid})
        self.assertEqual(len(page["items"]), 2)
        self.assertEqual(page["items"][0]["messageId"], accepted["messageId"])
        self.assertEqual(self.request(client, "draft.get", {"conversationId": cid})["text"], "szkic hjkl")
        self.operation(client, opid, "sent")
        client.close()
        self.assertEqual(client.process.stderr.read() if not client.process.stderr.closed else b"", b"")

    def test_crash_after_dispatch_keeps_unknown_without_resending_on_reconnect(self):
        client = self.start(sendCrash=True)
        client.state("ready")
        cid = self.request(client, "conversations.page")["items"][0]["conversationId"]
        op = self.request(client, "message.send", {"conversationId": cid, "text": "jedna próba"})
        client.state("reconnecting")
        client.state("ready")
        self.operation(client, op["operationId"], "unknown")
        rows = [json.loads(line) for line in self.record.read_text().splitlines()]
        self.assertEqual(sum(r["kind"] == "send" for r in rows), 1)
        client.send("unsafe", "operation.retry", {"operationId": op["operationId"]})
        self.assertEqual(client.reply("unsafe")["error"]["code"], "retry_unsafe")

    def test_timeout_late_reply_reconciles_and_releases_queue_without_resend(self):
        # Real production deadline (60 seconds), no test-only timing in bridge.
        client = self.start(sendDelay=61)
        client.state("ready")
        cid = self.request(client, "conversations.page")["items"][0]["conversationId"]
        op = self.request(client, "message.send", {"conversationId": cid, "text": "późny wynik"})
        client.read(lambda v: v.get("name") == "operation.changed" and v["data"]["operationId"] == op["operationId"])
        self.operation(client, op["operationId"], "unknown", seconds=62)
        self.operation(client, op["operationId"], "sent", seconds=5)
        rows = [json.loads(line) for line in self.record.read_text().splitlines()]
        self.assertEqual(sum(r["kind"] == "send" for r in rows), 1)

    def test_storage_failure_stops_receive_before_next_event_and_requires_retry(self):
        code = """
import sys
sys.path.insert(0, sys.argv.pop(1))
import signal_backend
class FailingStore(signal_backend.Store):
    def receive(self, account, value):
        super().receive(account, value)
        self.db.execute('PRAGMA query_only=ON')
signal_backend.Store = FailingStore
raise SystemExit(signal_backend.main())
"""
        command = [sys.executable, "-B", "-c", code, str(ROOT / "services"), "--test-scenario", str(self.fixture)]
        client = self.start(command=command, receiveEvents=[event(timestamp=1790000000000 + i) for i in range(3)])
        self.assertEqual(client.state("failed")["data"]["errorCode"], "storage_error")
        time.sleep(.15)
        with closing(sqlite3.connect(Path(self.env["XDG_DATA_HOME"]) / "putkin/signal/history.sqlite3")) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM messages").fetchone()[0], 1)
        rows = [json.loads(line) for line in self.record.read_text().splitlines()]
        self.assertEqual(sum(r["kind"] == "subscribe" for r in rows), 1)
        self.assertEqual(sum(r["kind"] == "exit" for r in rows), 1)
        client.send("page", "conversations.page")
        self.assertEqual(client.reply("page")["error"]["code"], "storage_error")

    def test_retention_preflight_sends_with_confirmed_timer_and_expires_old_result(self):
        client = self.start(expiration=60, sendResult=send_result(int(time.time() * 1000) - 120000))
        client.state("ready")
        cid = self.request(client, "conversations.page")["items"][0]["conversationId"]
        op = self.request(client, "message.send", {"conversationId": cid, "text": "staging"})
        status = self.operation(client, op["operationId"], "sent")
        self.assertEqual(status["errorCode"], "")
        message = self.request(client, "message.get", {"messageId": op["messageId"]})
        self.assertIsNone(message["text"])
        rows = [json.loads(line) for line in self.record.read_text().splitlines()]
        self.assertTrue(any(r["kind"] == "send" for r in rows))
        self.assertEqual(message["kind"], "expired")

    def test_deadline_cleanup_runs_without_polling_or_another_ui_request(self):
        # Shorten only the imported staging TTL in an explicit subprocess harness.
        code = """
import sys
sys.path.insert(0, sys.argv.pop(1))
import signal_outbox
signal_outbox.OUTBOX_TTL = 150
import signal_backend
raise SystemExit(signal_backend.main())
"""
        command = [sys.executable, "-B", "-c", code, str(ROOT / "services"), "--test-scenario", str(self.fixture)]
        client = self.start(command=command, sendDelay=1)
        client.state("ready")
        cid = self.request(client, "conversations.page")["items"][0]["conversationId"]
        op = self.request(client, "message.send", {"conversationId": cid, "text": "staging deadline"})
        time.sleep(.3)  # No IPC read/write drives this cleanup.
        with closing(sqlite3.connect(Path(self.env["XDG_DATA_HOME"]) / "putkin/signal/history.sqlite3")) as db:
            row = db.execute("SELECT kind,body FROM messages WHERE message_id=?", (op["messageId"],)).fetchone()
            self.assertEqual(row, ("expired", None))
        self.operation(client, op["operationId"], "sent")
        self.assertIsNone(self.request(client, "message.get", {"messageId": op["messageId"]})["text"])




if __name__ == "__main__":
    unittest.main()
