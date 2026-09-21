"""S03 real bridge/SQLite/pipes + synthetic CLI. No phone, network or stored QR."""
import ctypes
import json
import os
from pathlib import Path
import secrets
import sqlite3
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from urllib.parse import urlencode

from test_signal_lifecycle import Client, ROOT, environment, gone
from signal_qr_decode import decode, render
from signal_qr import modules
from signal_transport import Failure


class PairingTests(unittest.TestCase):
    def setUp(self):
        ctypes.CDLL(None).prctl(36, 1, 0, 0, 0)
        self.tmp = tempfile.TemporaryDirectory(prefix="pk-signal-link-")
        self.base = Path(self.tmp.name)
        self.env = environment(self.base)
        self.fixture = self.base / "scenario.json"
        self.record = self.base / "processes.jsonl"
        self.linked = self.base / "linked"
        self.gate = self.base / "scan"
        self.clients = []
        self.config = {"format": 1, "synthetic": True, "accounts": [], "receiveEvents": [],
                       "record": str(self.record), "linkedFile": str(self.linked), "linkGate": str(self.gate)}
        self.fixture.write_text(json.dumps(self.config))
        self.counter = 0

    def tearDown(self):
        for client in self.clients:
            client.close()
        for item in self.records("start"):
            self.assertTrue(gone(item["pid"]), "owned CLI remains")
        self.tmp.cleanup()

    def records(self, kind):
        return [v for v in map(json.loads, self.record.read_text().splitlines()) if v["kind"] == kind] if self.record.exists() else []

    def start(self, timeout=None):
        command = None
        if timeout:
            command = [sys.executable, "-B", "-c",
                "import sys;sys.path.insert(0,sys.argv[1]);import signal_account,signal_backend;"
                "signal_account.LINK_SECONDS=float(sys.argv[2]);"
                "sys.argv=['signal_backend','--test-scenario',sys.argv[3]];raise SystemExit(signal_backend.main())",
                str(ROOT / "services"), str(timeout), str(self.fixture)]
        client = Client(self.env, self.fixture, command=command)
        self.clients.append(client)
        return client

    def call(self, client, method, params=None):
        self.counter += 1
        rid = "request-" + str(self.counter)
        client.send(rid, method, params)
        return client.reply(rid)

    def begin(self, client):
        result = self.call(client, "account.link.start", {"deviceName": "Putkin hjkl"})
        self.assertIn("result", result)
        qr = client.read(lambda v: v.get("name") == "account.link.qr")
        self.assertEqual(qr["data"]["attemptId"], result["result"]["attemptId"])
        return result["result"]["attemptId"], qr["data"]["modules"]

    def test_qr_roundtrip_independent_decoder_and_missing_library(self):
        uri = "sgnl://linkdevice?" + urlencode({"uuid": secrets.token_hex(16), "pub_key": secrets.token_urlsafe(44)})
        self.assertTrue(decode(render(modules(uri))) == uri, "QR payload differs")
        with patch("signal_qr.ctypes.CDLL", side_effect=OSError):
            with self.assertRaisesRegex(Failure, "qr_unavailable"):
                modules(uri)
        for value in (None, "https://example.invalid", "sgnl://linkdevice?uuid=a", uri + "\n"):
            with self.assertRaisesRegex(Failure, "invalid_link"):
                modules(value)

    def test_success_double_click_directory_and_restart_without_repairing(self):
        self.config["contacts"] = [{"number": "+12025550100", "uuid": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                                    "name": "Kontakt", "profile": {"givenName": "Profil", "familyName": "Test"}}]
        self.config["groups"] = [{"id": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "name": "Grupa"}]
        self.fixture.write_text(json.dumps(self.config))
        client = self.start()
        client.state("idle")
        attempt, qr = self.begin(client)
        uri = decode(render(qr))
        self.assertTrue(uri.startswith("sgnl://linkdevice?"))
        result = self.call(client, "account.link.start", {"deviceName": "Duplicate"})
        self.assertEqual(result["result"]["attemptId"], attempt)
        self.gate.touch()
        state = client.state("ready")["data"]
        self.assertEqual(state["accountState"], "linked")
        self.assertFalse(state["linkAttempt"])
        directory = self.call(client, "account.directory")["result"]
        self.assertEqual(directory["contacts"][0]["profileName"], "Profil Test")
        self.assertEqual(directory["groups"][0]["name"], "Grupa")
        self.assertEqual(self.call(client, "conversations.page")["result"]["items"], [])
        client.close()
        restarted = self.start()
        self.assertEqual(restarted.state("ready")["data"]["accountId"], state["accountId"])
        self.assertEqual(len(self.records("link-start")), 1)
        self.assertEqual(len(self.records("link-finish")), 1)
        self.assertEqual(len(self.records("sync")), 1)
        self.assertEqual(len(self.records("subscribe")), 2)
        # Scan all persisted test data, never print the decoded value on failure.
        for path in self.base.rglob("*"):
            if path.is_file():
                self.assertFalse(uri.encode() in path.read_bytes(), "pairing URI persisted")
        config = Path(self.env["XDG_CONFIG_HOME"]) / "putkin/signal.json"
        self.assertEqual(config.stat().st_mode & 0o777, 0o600)
        self.assertEqual(json.loads(config.read_text())["deviceName"], "Putkin hjkl")

    def test_cancel_reaps_attempt_stale_cancel_and_retry(self):
        client = self.start()
        client.state("idle")
        attempt, _ = self.begin(client)
        pid = self.records("link-start")[-1]["pid"]
        self.assertEqual(self.call(client, "account.link.cancel", {"attemptId": "old"})["error"]["code"], "stale_attempt")
        self.call(client, "account.link.cancel", {"attemptId": attempt})
        cancelled = client.read(lambda v: v.get("data", {}).get("serviceState") == "idle" and not v["data"].get("linkAttempt")
                    and not v["data"].get("reconciling"))
        self.assertEqual(cancelled["data"]["linkError"], "cancelled")
        self.assertTrue(gone(pid))
        self.assertFalse(self.linked.exists())
        next_attempt, _ = self.begin(client)
        self.assertNotEqual(attempt, next_attempt)
        self.gate.touch()
        client.state("ready")

    def test_timeout_clears_secret_reconciles_and_does_not_automatically_retry_link(self):
        client = self.start(timeout=.25)
        client.state("idle")
        self.begin(client)
        state = client.read(lambda v: v.get("data", {}).get("linkError") == "link_expired"
                            and v["data"].get("serviceState") == "idle")["data"]
        self.assertFalse(state["linkAttempt"])
        self.assertFalse(state["reconciling"])
        self.assertEqual(len(self.records("link-start")), 1)
        self.assertEqual(len(self.records("subscribe")), 0)

    def test_lost_finish_reply_reconciles_persisted_account(self):
        self.config["linkCrash"] = True
        self.fixture.write_text(json.dumps(self.config))
        client = self.start()
        client.state("idle")
        self.begin(client)
        self.gate.touch()
        state = client.state("ready")["data"]
        self.assertEqual(state["accountState"], "linked")
        self.assertFalse(state["linkError"])
        self.assertEqual(len(self.records("link-start")), 1)
        self.assertGreaterEqual(len(self.records("accounts")), 3)

    def test_disable_persists_and_history_deletion_is_separate(self):
        from test_signal_history import event
        from test_signal_receipts import receipt
        self.linked.touch()
        client = self.start()
        state = client.state("ready")["data"]
        cid = self.call(client, "conversation.open", {"kind": "note"})["result"]["conversationId"]
        self.call(client, "draft.set", {"conversationId": cid, "text": "SYNTHETIC_PRIVATE_DRAFT", "expectedRevision": 0})
        self.call(client, "reply.draft.set", {"conversationId": cid, "text": "SYNTHETIC_PRIVATE_REPLY", "expectedRevision": 0})
        self.call(client, "conversation.notifications", {"conversationId": cid, "muted": True})
        self.call(client, "test.echo", {"receive": event()})
        direct = next(c for c in self.call(client, "conversations.page")["result"]["items"] if c["kind"] == "direct")
        incoming = self.call(client, "messages.page", {"conversationId": direct["conversationId"]})["result"]["items"][0]
        self.call(client, "messages.read", {"conversationId": direct["conversationId"], "messageIds": [incoming["messageId"]]})
        self.call(client, "test.echo", {"receive": receipt("read", [1790000002000])})
        self.assertEqual(self.call(client, "account.history.clear")["error"]["code"], "not_disabled")
        self.call(client, "account.configure", {"enabled": False})
        client.state("disabled")
        self.assertEqual(self.call(client, "draft.get", {"conversationId": cid})["result"]["text"], "SYNTHETIC_PRIVATE_DRAFT")
        client.close()
        client = self.start()
        client.state("disabled")
        self.assertEqual(self.call(client, "account.history.clear")["error"]["code"], "confirmation_required")
        self.assertTrue(self.call(client, "account.history.clear", {"confirm": "delete-local-history", "accountId": state["accountId"]})["result"]["cleared"])
        self.assertTrue(self.linked.exists())
        from contextlib import closing
        import sqlite3
        with closing(sqlite3.connect(Path(self.env["XDG_DATA_HOME"]) / "putkin/signal/history.sqlite3")) as db:
            for table in ("read_queue", "read_markers", "receipt_reports", "message_recipients"):
                self.assertEqual(db.execute("SELECT COUNT(*) FROM " + table).fetchone()[0], 0)
        for path in (Path(self.env["XDG_DATA_HOME"]) / "putkin/signal").glob("history.sqlite3*"):
            self.assertNotIn(b"SYNTHETIC_PRIVATE_DRAFT", path.read_bytes())
            self.assertNotIn(b"SYNTHETIC_PRIVATE_REPLY", path.read_bytes())
        self.call(client, "account.configure", {"enabled": True})
        self.assertEqual(client.state("ready")["data"]["accountId"], state["accountId"])
        self.assertFalse(self.records("link-start"))

    def test_revoked_account_refresh_preserves_history_and_stops_receiver(self):
        self.linked.touch()
        revoked = self.base / "revoked"
        self.config["revokedFile"] = str(revoked)
        self.fixture.write_text(json.dumps(self.config))
        client = self.start()
        state = client.state("ready")["data"]
        revoked.touch()
        self.call(client, "account.refresh")
        state = client.state("failed")["data"]
        self.assertEqual(state["accountState"], "relinkRequired")
        self.assertEqual(state["errorCode"], "relink_required")
        self.assertTrue(state["accountId"])
        self.assertTrue(gone(self.records("subscribe")[-1]["pid"]))

    def test_process_restart_during_pairing_requires_fresh_attempt(self):
        client = self.start()
        client.state("idle")
        self.begin(client)
        client.close()
        client = self.start()
        state = client.state("idle")["data"]
        self.assertEqual(state["accountState"], "unlinked")
        self.assertFalse(state["linkAttempt"])
        self.assertEqual(len(self.records("link-start")), 1)

    def test_transport_failure_preserves_linked_identity(self):
        self.linked.touch()
        client = self.start()
        before = client.state("ready")["data"]
        self.call(client, "test.echo", {"fault": "crash"})
        offline = client.state("reconnecting")["data"]
        self.assertEqual(offline["accountState"], "linked")
        self.assertEqual(offline["accountId"], before["accountId"])
        self.assertNotEqual(offline["errorCode"], "relink_required")
        self.assertEqual(client.state("ready")["data"]["accountId"], before["accountId"])

    def test_config_validation_preserves_previous_file_and_rejects_symlink(self):
        client = self.start()
        client.state("idle")
        for params in ({"enabled": "true"}, {"javaHome": "relative"}, {"executable": "./cli"},
                       {"deviceName": ""}, {"deviceName": "name\nsecret"}, {"unknown": True}):
            self.assertIn("error", self.call(client, "account.configure", params))
        path = Path(self.env["XDG_CONFIG_HOME"]) / "putkin/signal.json"
        self.assertFalse(path.exists())
        target = self.base / "do-not-touch"
        target.write_text("SYNTHETIC_UNRELATED_FILE")
        path.symlink_to(target)
        self.assertIn("error", self.call(client, "account.configure", {"enabled": True}))
        self.assertEqual(target.read_text(), "SYNTHETIC_UNRELATED_FILE")


if __name__ == "__main__":
    unittest.main()
