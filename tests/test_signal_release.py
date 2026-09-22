"""S12: release compatibility on real synthetic SQLite/files, never live accounts."""
from contextlib import closing
import copy
import json
import os
import runpy
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "services"), str(ROOT / "scripts")]
import _install
import _signal_install
import signal_release
from signal_paths import StoreLease
from signal_store import Store, SCHEMA_VERSION
from signal_transport import Failure
from test_signal_lifecycle import environment, Client, gone
from test_signal_history import event, OWN, PEER


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="pk-release-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.env = environment(self.base)
        self.environment = patch.dict(os.environ, self.env)
        self.environment.start()
        self.addCleanup(self.environment.stop)
        mask = os.umask(0o077)
        self.addCleanup(os.umask, mask)
        self.lease = StoreLease()
        self.addCleanup(self.lease.close)
        self.assertTrue(self.lease.acquire())
        self.spec = signal_release.release_spec()

    def test_upgrade_v1_and_code_rollback_preserve_keys_drafts_and_deleted_content(self):
        db = self.lease.data / "history.sqlite3"
        with closing(sqlite3.connect(db)) as connection:
            connection.executescript((ROOT / "services/signal_schema.sql").read_text())
        before = signal_release.compatibility(self.lease.data, self.spec)
        self.assertEqual(before["schema"], 1)
        signal_release.claim_release(self.lease)
        protocol = self.lease.data / "cli/protocol-synthetic"
        protocol.parent.mkdir()
        protocol.write_bytes(b"synthetic ratchet after send - never restore")
        store = Store(self.lease, clock=lambda: 1790000100000)
        account = store.bind_account(OWN, "+12025550100")
        store.receive(account, event(body="S12 synthetic deleted message"))
        cid = store.open_conversation(account, {"kind": "direct", "serviceId": PEER})["conversationId"]
        message = store.page(account, {"conversationId": cid}, messages=True)["items"][0]
        store.set_draft(account, {"conversationId": cid, "text": "S12 synthetic draft", "expectedRevision": 0})
        import signal_retention
        signal_retention.local_delete(store, account, {"conversationId": cid, "messageId": message["messageId"]})
        store.close()
        # A same-contract older code release uses current data; no snapshot.
        self.assertEqual(signal_release.compatibility(self.lease.data, self.spec)["schema"], SCHEMA_VERSION)
        signal_release.claim_release(self.lease)
        store = Store(self.lease, clock=lambda: 1790000100000)
        try:
            self.assertEqual(store.draft(account, cid)["text"], "S12 synthetic draft")
            store.receive(account, event(body="S12 synthetic deleted message"))
            self.assertNotIn("S12 synthetic deleted message", json.dumps(store.page(account, {"conversationId": cid}, messages=True)))
            self.assertEqual(protocol.read_bytes(), b"synthetic ratchet after send - never restore")
        finally:
            store.close()

    def test_downgrades_are_refused_without_touching_data(self):
        signal_release.claim_release(self.lease)
        store = Store(self.lease)
        store.close()
        before = {p.name: p.read_bytes() for p in self.lease.data.iterdir() if p.is_file()}
        for change, error in (({"schemaMax": 6}, "schematu"), ({"cliStore": "signal-cli-older"}, "signal-cli"),
                              ({"retention": 1}, "retencji")):
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, error):
                signal_release.compatibility(self.lease.data, {**self.spec, **change})
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.lease.data.iterdir() if p.is_file()})
        self.assertEqual(signal_release.compatibility(self.lease.data, None)["signal"], "unavailable")

    def test_wal_schema_is_checked_and_dry_run_does_not_modify_database(self):
        db = self.lease.data / "history.sqlite3"
        with closing(sqlite3.connect(db)) as connection:
            connection.execute("PRAGMA journal_mode=WAL")
            connection.execute("PRAGMA wal_autocheckpoint=0")
            connection.execute("PRAGMA user_version=99")
            connection.commit()
            before = {p.name: p.read_bytes() for p in self.lease.data.iterdir() if p.is_file()}
            with self.assertRaisesRegex(ValueError, "baza v99"):
                signal_release.compatibility(self.lease.data, self.spec)
            self.assertEqual(before, {p.name: p.read_bytes() for p in self.lease.data.iterdir() if p.is_file()})

    def test_installer_refuses_live_receiver_and_legacy_unversioned_signal(self):
        layout = {"store": self.lease.data.parent}
        with self.assertRaisesRegex(RuntimeError, "nadal używa"):
            with _signal_install.handoff(layout, ROOT):
                self.fail("must not publish")
        legacy = self.base / "legacy/services"
        legacy.mkdir(parents=True)
        (legacy / "SignalBackend.qml").write_text("legacy")
        with self.assertRaisesRegex(ValueError, "bez kontraktu"):
            signal_release.release_spec(legacy.parent)
        (self.lease.data / "cli").mkdir()
        (self.lease.data / "cli/account").write_text("synthetic")
        with self.assertRaisesRegex(ValueError, "bez kontraktu"):
            signal_release.compatibility(self.lease.data, self.spec)

    def test_symlink_and_corrupt_history_fail_closed(self):
        db = self.lease.data / "history.sqlite3"
        db.symlink_to(self.base / "outside")
        with self.assertRaisesRegex(ValueError, "Dowiązanie"):
            signal_release.compatibility(self.lease.data, self.spec)
        db.unlink()
        db.write_bytes(b"corrupt synthetic database")
        with self.assertRaises(sqlite3.DatabaseError):
            signal_release.compatibility(self.lease.data, self.spec)

    def test_runtime_full_tree_and_executable_bits_are_pinned(self):
        bundle = self.base / "runtime"
        (bundle / "cli/bin").mkdir(parents=True)
        binary = bundle / "cli/bin/signal-cli"
        binary.write_text("synthetic")
        binary.chmod(0o700)
        source = self.base / "source"
        policy = source / "services/signal-cli-media/distribution.json"
        policy.parent.mkdir(parents=True)
        pin = json.loads((ROOT / "services/signal-cli-media/distribution.json").read_text())
        pin["treeSha256"] = signal_release.tree_digest(signal_release.tree(bundle))
        policy.write_text(json.dumps(pin))
        self.assertEqual(signal_release.verify_runtime(bundle, source)["cliVersion"], "0.14.8")
        for data, mode in (("modified", 0o700), ("synthetic", 0o600)):
            binary.write_text(data); binary.chmod(mode)
            with self.assertRaisesRegex(ValueError, "runtime Signala"):
                signal_release.verify_runtime(bundle, source)
        binary.write_text("synthetic"); binary.chmod(0o700)
        (bundle / "account.json").write_text("must not package user data")
        with self.assertRaises(ValueError):
            signal_release.verify_runtime(bundle, source)

    def test_runtime_resolution_does_not_inherit_jvm_injection_or_modify_preferences(self):
        config = {"enabled": True, "executable": "/usr/bin/true", "javaHome": "/tmp/synthetic-java"}
        original = copy.deepcopy(config)
        with patch.dict(os.environ, {"JAVA_TOOL_OPTIONS": "private", "JAVA_OPTS": "private", "JDK_JAVA_OPTIONS": "private"}):
            command, env = signal_release.command(config)
        self.assertEqual(command, ["/usr/bin/true"])
        self.assertEqual(env["JAVA_HOME"], "/tmp/synthetic-java")
        self.assertNotIn("JAVA_TOOL_OPTIONS", env)
        self.assertNotIn("JDK_JAVA_OPTIONS", env)
        self.assertEqual(config, original)

    def test_release_schema_matches_reader(self):
        self.assertEqual(self.spec["schemaMax"], SCHEMA_VERSION)

    def test_expiration_after_code_rollback_runs_before_history_publication(self):
        from test_signal_retention import disappearing, T
        signal_release.claim_release(self.lease)
        store = Store(self.lease, clock=lambda: T + 1000)
        account = store.bind_account(OWN, "+12025550100")
        store.receive(account, disappearing(phone=True, start=T, body="S12 expiring synthetic"))
        store.close()
        signal_release.compatibility(self.lease.data, self.spec)
        signal_release.claim_release(self.lease)
        store = Store(self.lease, clock=lambda: T + 60000)
        try:
            self.assertNotIn("S12 expiring synthetic", "\n".join(store.db.iterdump()))
            store.receive(account, disappearing(phone=True, start=T, body="S12 expiring synthetic"))
            self.assertNotIn("S12 expiring synthetic", "\n".join(store.db.iterdump()))
        finally:
            store.close()


class InstallCompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="pk-compat-install-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.layout = _install.paths(self.base / "destination")
        self.store = self.layout["store"]
        self.spec = signal_release.release_spec()
        self.builds = []
        # Tiny synthetic release manifests exercise the real installation
        # transaction. Real CLI/JRE integrity is tested by test-signal-release.
        for number in (6, 7):
            build = self.store / f"releases/20260921-00000{number}-00000000000{number}"
            (build / "services").mkdir(parents=True)
            (build / "shell.qml").write_text("import Quickshell\nShellRoot {}\n")
            (build / "services/signal-release.json").write_text(json.dumps({**self.spec, "schemaMax": number}))
            (build / _install.MARKER).write_text(json.dumps({"format": 1, "files": _install.manifest(build)}))
            self.builds.append(build)
        self.main = runpy.run_path(str(ROOT / "scripts/install"))["main"]

    def data_version(self, version):
        data = self.store / "signal"
        data.mkdir(exist_ok=True)
        (data / "release.json").write_text(json.dumps({**self.spec, "schemaMax": version}))
        with closing(sqlite3.connect(data / "history.sqlite3")) as db:
            db.execute(f"PRAGMA user_version={version}")

    def test_cli_restore_refuses_downgrade_before_switching_pointer(self):
        old, new = self.builds
        _install.publish(self.store, old)
        _install.publish(self.store, new)
        self.data_version(7)
        with patch.dict(self.main.__globals__, paths=lambda _: self.layout, dependencies=lambda: {}, runtime=lambda *_, **__: (None, None)), \
                patch.object(sys, "argv", ["install", "--restore", "--dry-run"]):
            with self.assertRaisesRegex(ValueError, "Downgrade schematu"):
                self.main()
        self.assertEqual(_install.current(self.store), new)

    def test_failed_start_after_migration_does_not_restart_incompatible_fallback(self):
        old, new = self.builds
        _install.publish(self.store, old)
        self.data_version(6)
        session = Mock()
        session.old_build = old
        session.old = {"config_path": str(old / "shell.qml")}
        def failed_start():
            self.data_version(7)
            raise RuntimeError("synthetic failure after migration")
        session.start.side_effect = failed_start
        with patch.dict(self.main.__globals__, paths=lambda _: self.layout, dependencies=lambda: {}, runtime=lambda *_, **__: (None, None), Session=lambda _: session), \
                patch.object(_install, "validate"), \
                patch.object(sys, "argv", ["install", "--restore", new.name, "--activate"]):
            with self.assertRaisesRegex(ValueError, "Downgrade schematu"):
                self.main()
        self.assertEqual(session.start.call_count, 1)
        self.assertEqual(_install.current(self.store), new)
        with closing(sqlite3.connect(self.store / "signal/history.sqlite3")) as db:
            self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 7)


if __name__ == "__main__":
    unittest.main()
