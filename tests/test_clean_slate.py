"""Clean installation and crash recovery on private files; no host session writes."""
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, call

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import _clean_slate as clean
import _dotfiles as dots
import _install as installer


class CleanSlateTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="pk-clean-slate-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.layout = installer.paths(self.base / "target ' $ ` ;")
        self.config = self.layout["entry"].parent.parent
        self.source = self.base / "source"
        self.source.mkdir()
        self.files = []
        self.add("nvim/init.lua", "config:nvim/init.lua", "-- new editor")
        self.add("hypr/local.lua", "config:hypr/local.lua", "-- default monitors", "seed")
        self.add("putkin/settings.json", "config:putkin/settings.json", '{"fresh":true}', "seed")

    def add(self, source, target, text, policy="managed"):
        self.write(self.source / source, text)
        self.files.append({"source": source, "target": target, "policy": policy})
        self.write(self.source / "catalog.json", json.dumps({"format": 1, "files": self.files}))

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def plan(self):
        items = dots.plan(self.source, self.layout, clean_slate=True)
        roots, extra, info = clean.plan(self.layout, items, destination=True)
        return dots.Transaction(self.layout, items + extra, roots), info

    def install(self):
        transaction, info = self.plan()
        transaction.apply()
        transaction.commit()
        return transaction, info

    def test_reset_removes_old_fragments_and_resets_edits_and_seed(self):
        old = self.write(self.config / "nvim/lua/old.lua", "-- obsolete plugin")
        old.chmod(0o640)
        self.write(self.config / "nvim/init.lua", "-- locally edited")
        self.write(self.config / "hypr/local.lua", "-- old device")
        self.write(self.config / "hypr/monitors.lua", "-- no migration in clean mode")
        self.write(self.config / "hypr/hyprland.conf", "exec-once = waybar")
        self.write(self.config / "putkin/obsolete.json", "{}")
        self.write(self.config / "putkin/settings.json", '{"old":true}')
        self.write(self.config / "quickshell-de/shell.qml", "old desktop")
        self.write(self.config / "quickshell/shell.qml", "old default")
        self.write(self.layout["launcher"], "#!/bin/sh\nold-shell\n")
        self.write(self.layout["state"] / "config-files.json", "broken old bookkeeping")
        transaction, info = self.install()
        self.assertEqual((self.config / "nvim/init.lua").read_text(), "-- new editor")
        self.assertEqual((self.config / "hypr/local.lua").read_text(), "-- default monitors")
        self.assertEqual((self.config / "putkin/settings.json").read_text(), '{"fresh":true}')
        for path in (old, self.config / "hypr/hyprland.conf", self.config / "hypr/monitors.lua",
                     self.config / "quickshell-de", self.config / "putkin/obsolete.json"):
            self.assertFalse(path.exists(), path)
        self.assertEqual(self.layout["launcher"].read_bytes(), (ROOT / "scripts/qs").read_bytes())
        self.assertEqual(transaction.backup.stat().st_mode & 0o777, 0o700)
        record = json.loads((transaction.backup / "manifest.json").read_text())
        archived = next(i for i in record["resets"] if i["path"] == str(self.config / "nvim"))
        self.assertEqual((Path(archived["backup"]) / "lua/old.lua").read_text(), "-- obsolete plugin")
        self.assertEqual((Path(archived["backup"]) / "lua/old.lua").stat().st_mode & 0o777, 0o640)
        self.assertIn("waybar.service", info["maskedUnits"])
        self.assertEqual([i["action"] for i in dots.plan(self.source, self.layout)], ["unchanged"] * 3)

    def test_keys_accounts_private_values_and_browser_data_stay_in_place(self):
        self.add("apps/zen/chrome/userChrome.css", "zen:chrome/userChrome.css", "new css")
        self.add("apps/zen/user.js", "zen:user.js", 'user_pref("browser.tabs.warnOnClose", false);')
        self.write(self.config / "zen/profiles.ini", "[Profile0]\nPath=local.default\nDefault=1\nIsRelative=1\n")
        profile = self.config / "zen/local.default"
        self.write(profile / "chrome/old-theme.css", "old css")
        secrets = [self.layout["home"] / ".ssh/id_ed25519", self.layout["home"] / ".gnupg/private-keys-v1.d/a.key",
                   self.config / "voxtype/token", self.config / "fish/fish_variables",
                   self.config / "hypr/private.key", self.config / "putkin/signal/secret",
                   self.config / "Signal/storage/key", self.layout["store"] / "signal/history.sqlite3",
                   profile / "cookies.sqlite", profile / "key4.db", profile / "prefs.js", profile / "logins.json",
                   self.config / "gtk-3.0/bookmarks", self.config / "unrelated-app/settings.conf"]
        before = {}
        for path in secrets:
            self.write(path, "private-canary")
            before[path] = (path.read_bytes(), path.stat().st_ino, path.stat().st_mtime_ns)
        transaction, _ = self.install()
        for path in secrets:
            self.assertEqual((path.read_bytes(), path.stat().st_ino, path.stat().st_mtime_ns), before[path])
        self.assertFalse((profile / "chrome/old-theme.css").exists())
        self.assertEqual((profile / "chrome/userChrome.css").read_text(), "new css")
        for path in transaction.backup.rglob("*"):
            if path.is_file() and not path.is_symlink():
                self.assertNotIn(b"private-canary", path.read_bytes())

    def test_legacy_autostarts_units_and_overrides_are_disabled_and_restorable(self):
        old_desktop = self.write(self.config / "autostart/old-shell.desktop", "[Desktop Entry]\nExec=env A=b /usr/bin/quickshell -c old\n")
        unrelated = self.write(self.config / "autostart/notes.desktop", '[Desktop Entry]\nExec=notify-send "waybar is a program"\n')
        unit = self.write(self.config / "systemd/user/my-panel.service", "[Service]\nExecStart=/usr/bin/waybar\n")
        override = self.write(self.config / "systemd/user/my-panel.service.d/old.conf", "[Service]\nRestart=always\n")
        enabled = self.config / "systemd/user/graphical-session.target.wants/my-panel.service"
        enabled.parent.mkdir()
        enabled.symlink_to("../my-panel.service")
        before = {p: p.read_bytes() for p in (old_desktop, unrelated, unit, override)}
        transaction, info = self.install()
        self.assertEqual(str(unit.readlink()), "/dev/null")
        self.assertFalse(enabled.is_symlink())
        self.assertFalse(override.exists())
        self.assertIn("Hidden=true", old_desktop.read_text())
        self.assertEqual(unrelated.read_bytes(), before[unrelated])
        self.assertIn("my-panel.service", info["maskedUnits"])
        result = subprocess.run([ROOT / "scripts/restore-config", "--destination", self.layout["home"].parent,
                                 "--backup", transaction.backup], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        for path, original in before.items():
            self.assertEqual(path.read_bytes(), original)
        self.assertEqual(str(enabled.readlink()), "../my-panel.service")
        self.assertFalse((self.config / "systemd/user/waybar.service").is_symlink())

    def test_global_autostart_gets_user_hidden_override_without_global_write(self):
        directory = self.base / "etc/xdg/autostart"
        vendor = self.write(directory / "vendor-panel.desktop", "[Desktop Entry]\nExec=waybar\n")
        items = dots.plan(self.source, self.layout, clean_slate=True)
        with patch.object(clean, "desktop_roots", return_value=([directory], [])):
            roots, extra, _ = clean.plan(self.layout, items)
        transaction = dots.Transaction(self.layout, items + extra, roots)
        transaction.apply()
        transaction.commit()
        self.assertIn("Hidden=true", (self.config / "autostart/vendor-panel.desktop").read_text())
        self.assertEqual(vendor.read_text(), "[Desktop Entry]\nExec=waybar\n")

    def test_symlink_roots_and_resources_do_not_copy_or_change_external_targets(self):
        outside = self.write(self.base / "external/private", "external-key-canary").parent
        self.config.mkdir(parents=True)
        (self.config / "nvim").symlink_to(outside)
        self.write(self.config / "hypr/old.lua", "old module")
        (self.config / "hypr/resources").symlink_to(outside)
        transaction, _ = self.plan()
        transaction.apply()
        self.assertEqual((self.config / "nvim/init.lua").read_text(), "-- new editor")
        self.assertEqual((outside / "private").read_text(), "external-key-canary")
        for path in transaction.backup.rglob("*"):
            if path.is_file() and not path.is_symlink():
                self.assertNotIn(b"external-key-canary", path.read_bytes())
        transaction.rollback()
        self.assertEqual((self.config / "nvim").readlink(), outside)
        self.assertEqual((self.config / "hypr/resources").readlink(), outside)
        self.assertEqual(list(outside.iterdir()), [outside / "private"])

    def test_backup_failure_never_removes_old_configuration(self):
        old = self.write(self.config / "nvim/old.lua", "original")
        transaction, _ = self.plan()
        with patch.object(clean.shutil, "copytree", side_effect=OSError("backup full")):
            with self.assertRaisesRegex(OSError, "backup full"):
                transaction.apply()
        self.assertEqual(old.read_text(), "original")
        self.assertFalse(transaction.pending.exists())

    def test_process_death_during_removal_and_writes_recovers_complete_trees(self):
        self.write(self.config / "nvim/old/subdir/custom.lua", "old plugin")
        self.write(self.config / "hypr/monitors.lua", "old monitors")
        before = {p: p.read_bytes() for p in self.config.rglob("*") if p.is_file()}
        script = '''
import os,sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
import _clean_slate as clean, _dotfiles as dots
from _install import paths
layout=paths(Path(sys.argv[3]))
items=dots.plan(Path(sys.argv[2]),layout,clean_slate=True)
roots,extra,_=clean.plan(layout,items,destination=True)
if sys.argv[4]=='remove':
    real=clean.remove_reset
    def remove(layout,path):
        real(layout,path)
        if path.name=='nvim': os._exit(73)
    clean.remove_reset=remove
else:
    real=dots.atomic_file
    def write(path,*args):
        real(path,*args)
        if path.name=='local.lua': os._exit(73)
    dots.atomic_file=write
dots.Transaction(layout,items+extra,roots).apply()
'''
        for moment in ("remove", "write"):
            with self.subTest(moment=moment):
                result = subprocess.run([sys.executable, "-c", script, ROOT / "scripts", self.source,
                                         self.layout["home"].parent, moment])
                self.assertEqual(result.returncode, 73)
                dots.Transaction.recover(self.layout)
                for path, value in before.items():
                    self.assertEqual(path.read_bytes(), value)
                self.assertFalse((self.config / "nvim/init.lua").exists())
                self.assertFalse((self.config / "hypr/local.lua").exists())
                self.assertFalse((self.layout["state"] / "config-pending.json").exists())

    def test_dry_run_and_conflicting_flags_leave_destination_unchanged(self):
        destination = self.base / "never created"
        command = [ROOT / "scripts/install", "--destination", destination, "--clean-slate"]
        result = subprocess.run([*command, "--dry-run"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = json.loads(result.stdout)
        self.assertIn(str(destination / "config/hypr"), result["cleanSlate"]["reset"])
        self.assertIn("waybar.service", result["cleanSlate"]["maskedUnits"])
        self.assertFalse(destination.exists())
        for option in ("--activate", "--shell-only", "--restore", "--replace-config"):
            result = subprocess.run([*command, option], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(destination.exists())

    def test_failed_publication_restores_dotfiles_launcher_and_runtime(self):
        source = self.base / "runtime"
        for directory in (*installer.RUNTIME_DIRS, "scripts"):
            (source / directory).mkdir(parents=True)
        self.write(source / "shell.qml", "import Quickshell\nShellRoot {}")
        for name in ("lock-session", "ssh-askpass"):
            self.write(source / "scripts" / name, "#!/usr/bin/env python3\n")
        self.write(self.config / "nvim/old.lua", "previous settings")
        self.write(self.layout["entry"], "previous shell")
        self.write(self.layout["launcher"], "previous launcher")
        main = runpy.run_path(str(ROOT / "scripts/install"))["main"]
        args = ["install", "--clean-slate", "--source", str(source), "--config-source", str(self.source),
                "--destination", str(self.layout["home"].parent)]
        def failed_configure(layout):
            installer.configure(layout)
            raise RuntimeError("injected publish error")
        with patch.object(installer, "validate", side_effect=RuntimeError("invalid runtime")), \
                patch.object(sys, "argv", args), patch.dict(main.__globals__, dependencies=lambda: {}):
            with self.assertRaisesRegex(RuntimeError, "invalid runtime"):
                main()
        self.assertEqual(self.layout["entry"].read_text(), "previous shell")
        self.assertFalse((self.layout["state"] / "config-backups").exists())
        with patch.object(installer, "validate"), patch.object(sys, "argv", args), \
                patch.dict(main.__globals__, dependencies=lambda: {}, configure=failed_configure), \
                patch.object(clean.LegacyServices, "stop", side_effect=AssertionError("host service touched")):
            with self.assertRaisesRegex(RuntimeError, "injected publish error"):
                main()
        self.assertEqual(self.layout["entry"].read_text(), "previous shell")
        self.assertEqual(self.layout["launcher"].read_text(), "previous launcher")
        self.assertEqual((self.config / "nvim/old.lua").read_text(), "previous settings")
        self.assertIsNone(installer.current(self.layout["store"]))

    def test_reset_manifest_cannot_target_account_directory_or_linked_parent(self):
        secret = self.write(self.config / "Signal/storage/key", "private-canary")
        with self.assertRaisesRegex(ValueError, "Chronione"):
            clean.validate_resets(self.layout, [{"path": str(secret.parent.parent), "kind": "absent", "backup": None}])
        external = self.base / "external"
        external.mkdir()
        (self.config / "systemd").symlink_to(external)
        with self.assertRaisesRegex(ValueError, "Dowiązanie"):
            self.plan()
        self.assertEqual(secret.read_text(), "private-canary")
        self.assertEqual(list(external.iterdir()), [])

    def test_custom_catalog_uses_zen_target_not_source_name_to_select_reset(self):
        self.add("custom/browser.css", "zen:chrome/nested/theme.css", "new css")
        self.add("apps/zen/chrome/userChrome.css", "config:other/custom.css", "another config")
        self.write(self.config / "zen/profiles.ini", "[Profile0]\nPath=profiles/real.default\nDefault=1\n")
        old = self.write(self.config / "zen/profiles/real.default/chrome/old.css", "old theme")
        untouched = self.write(self.config / "other/keep.conf", "unrelated setting")
        self.install()
        self.assertFalse(old.exists())
        self.assertEqual((old.parent / "nested/theme.css").read_text(), "new css")
        self.assertEqual(untouched.read_text(), "unrelated setting")

    def test_overlapping_xdg_backup_or_runtime_is_rejected_before_reset(self):
        old = self.write(self.config / "nvim/old.lua", "old settings")
        for name in ("state", "store"):
            with self.subTest(name=name), patch.dict(self.layout, {name: self.config / "nvim/nested/putkin"}):
                with self.assertRaisesRegex(ValueError, "nakłada"):
                    self.plan()
            self.assertEqual(old.read_text(), "old settings")

    def test_logout_guard_and_legacy_service_failure_restore_only_identified_units(self):
        with patch.object(clean, "run", return_value="fish\nHyprland\n"):
            with self.assertRaisesRegex(RuntimeError, "TTY"):
                clean.require_logged_out()
        with patch.object(clean, "run", return_value="fish\npython3\n"):
            clean.require_logged_out()
        service = clean.LegacyServices(["waybar.service", "mako.service"])
        with patch.object(clean, "run", side_effect=["active", "", "inactive", "", ""]) as run:
            service.stop()
            service.rollback()
        self.assertEqual(run.call_args_list, [
            call(["systemctl", "--user", "show", "waybar.service", "-p", "ActiveState", "--value"]),
            call(["systemctl", "--user", "stop", "waybar.service"]),
            call(["systemctl", "--user", "show", "mako.service", "-p", "ActiveState", "--value"]),
            call(["systemctl", "--user", "daemon-reload"]),
            call(["systemctl", "--user", "start", "waybar.service"])])


if __name__ == "__main__":
    unittest.main()
