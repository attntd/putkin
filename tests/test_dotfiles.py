"""Private-filesystem installation, recovery and credential exclusion."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import _dotfiles as dots
from _install import paths


class DotfilesTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="pk-dotfiles-")
        self.addCleanup(tmp.cleanup)
        self.base = Path(tmp.name)
        self.layout = paths(self.base / "new user's $HOME `id` computer")
        self.config = self.layout["entry"].parent.parent
        self.source = self.base / "source"
        self.source.mkdir()
        self.files = []

    def add(self, name, target, text, policy="managed"):
        path = self.source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        self.files.append({"source": name, "target": target, "policy": policy})
        (self.source / "catalog.json").write_text(json.dumps({"format": 1, "files": self.files}))
        return path

    def install(self):
        transaction = dots.Transaction(self.layout, dots.plan(self.source, self.layout))
        transaction.apply()
        transaction.commit()
        return transaction

    def test_install_update_preserves_edits_machine_settings_and_secrets(self):
        editor = self.add("apps/nvim/init.lua", "config:nvim/init.lua", "-- editor v1")
        self.add("hypr/local.lua", "config:hypr/local.lua", "-- local defaults", "seed")
        secret = self.layout["home"] / ".ssh/id_ed25519"
        secret.parent.mkdir(parents=True)
        secret.write_bytes(b"private-key-canary")
        history = self.layout["store"] / "signal/history.sqlite3"
        history.parent.mkdir(parents=True)
        history.write_bytes(b"private-account-canary")
        self.assertEqual([i["action"] for i in dots.plan(self.source, self.layout)], ["install", "install"])
        self.assertFalse(self.config.exists())  # Planning creates nothing.
        self.install()
        target = self.config / "nvim/init.lua"
        target.write_text("-- edited on target")
        (self.config / "hypr/local.lua").write_text("-- this machine")
        editor.write_text("-- editor v2")
        self.assertEqual([i["action"] for i in dots.plan(self.source, self.layout)], ["preserve-local", "preserve-local"])
        self.install()
        self.assertEqual(target.read_text(), "-- edited on target")
        forced = dots.plan(self.source, self.layout, replace=True)
        self.assertEqual([i["action"] for i in forced], ["update", "preserve-local"])
        transaction = dots.Transaction(self.layout, forced)
        transaction.apply()
        transaction.commit()
        self.assertEqual(target.read_text(), "-- editor v2")
        self.assertEqual((self.config / "hypr/local.lua").read_text(), "-- this machine")
        self.assertEqual(secret.read_bytes(), b"private-key-canary")
        self.assertEqual(history.read_bytes(), b"private-account-canary")
        backup = json.loads((transaction.backup / "manifest.json").read_text())
        self.assertEqual(Path(backup["files"][0]["backup"]).read_text(), "-- edited on target")

    def test_failed_write_and_process_death_can_restore_old_files(self):
        self.add("a", "config:app/a", "new a")
        self.add("b", "config:app/b", "new b")
        target = self.config / "app/a"
        target.parent.mkdir(parents=True)
        target.write_text("original a")
        script = '''
import os,sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
import _dotfiles as dots
from _install import paths
layout=paths(Path(sys.argv[3]))
real=dots.atomic_file
def fail(path,*args):
    if path == layout['entry'].parent.parent/'app/b': os._exit(73)
    return real(path,*args)
dots.atomic_file=fail
dots.Transaction(layout,dots.plan(Path(sys.argv[2]),layout)).apply()
'''
        result = subprocess.run([sys.executable, "-c", script, ROOT / "scripts", self.source, self.layout["home"].parent])
        self.assertEqual(result.returncode, 73)
        self.assertEqual(target.read_text(), "new a")
        dots.Transaction.recover(self.layout)
        self.assertEqual(target.read_text(), "original a")
        self.assertFalse((self.config / "app/b").exists())
        self.assertFalse((self.layout["state"] / "config-pending.json").exists())

    def test_existing_zen_profile_receives_only_preferences_css_and_shortcuts(self):
        self.add("apps/zen/user.js", "zen:user.js", 'user_pref("browser.warnOnQuitShortcut", false);\n')
        self.add("apps/zen/chrome/userChrome.css", "zen:chrome/userChrome.css", "body {color: red}")
        self.add("apps/zen/zen-keyboard-shortcuts.json", "zen:zen-keyboard-shortcuts.json", '{"shortcuts":[]}')
        profile = self.config / "zen/another-machine.default"
        profile.mkdir(parents=True)
        ini = profile.parent / "profiles.ini"
        ini.write_text("[Profile0]\nIsRelative=1\nPath=another-machine.default\nDefault=1\n")
        (profile / "cookies.sqlite").write_bytes(b"private-cookie-canary")
        (profile / "prefs.js").write_text('user_pref("browser.warnOnQuitShortcut", true);\nuser_pref("auth.access_token", "private-token-canary");\n')
        (self.source / "not-catalogued-secret").write_text("private-source-canary")
        before = ini.read_bytes()
        self.install()
        self.assertTrue((profile / "chrome/userChrome.css").exists())
        self.assertEqual(ini.read_bytes(), before)
        self.assertEqual((profile / "cookies.sqlite").read_bytes(), b"private-cookie-canary")
        output = self.base / "exported"
        dots.export(self.source, self.layout, output)
        self.assertIn("true", (output / "apps/zen/user.js").read_text())
        for p in output.rglob("*"):
            if p.is_file():
                self.assertNotIn(b"private-", p.read_bytes())
        self.assertFalse((output / "not-catalogued-secret").exists())

    def test_fresh_zen_profile_is_discoverable_and_idempotent(self):
        self.add("apps/zen/user.js", "zen:user.js", 'user_pref("browser.warnOnQuitShortcut", false);\n')
        self.install()
        profile, ini = dots.zen_profile(self.config)
        self.assertEqual(profile, self.config / "zen/putkin.default")
        self.assertIsNone(ini)
        self.assertEqual(dots.plan(self.source, self.layout)[0]["action"], "unchanged")

    def test_secret_assignment_aborts_export_before_output_exists(self):
        self.add("apps/fish/config.fish", "config:fish/config.fish", "# safe config\n")
        self.install()
        (self.config / "fish/config.fish").write_text("set -gx CUSTOM_API_KEY private-token-canary\n")
        output = self.base / "must not exist"
        with self.assertRaisesRegex(ValueError, "sekret") as error:
            dots.export(self.source, self.layout, output)
        self.assertNotIn("private-token-canary", str(error.exception))
        self.assertFalse(output.exists())

    def test_path_traversal_credential_paths_and_symlinks_are_rejected(self):
        origin = self.add("a", "config:app/a", "safe")
        for target in ("config:../.ssh/id_ed25519", "home:.ssh/id_ed25519", "config:Signal/key4.db", "zen:cookies.sqlite", "data:putkin/signal/owner.lock"):
            self.files[0]["target"] = target
            (self.source / "catalog.json").write_text(json.dumps({"format": 1, "files": self.files}))
            with self.assertRaises(ValueError):
                dots.plan(self.source, self.layout)
        self.files[0]["target"] = "config:app/a"
        (self.source / "catalog.json").write_text(json.dumps({"format": 1, "files": self.files}))
        self.config.mkdir(parents=True)
        (self.config / "app").symlink_to(self.base)
        self.assertEqual(dots.plan(self.source, self.layout)[0]["action"], "replace-link")
        (self.config / "app").unlink()
        origin.unlink()
        origin.symlink_to(self.source / "catalog.json")
        with self.assertRaises(ValueError):
            dots.plan(self.source, self.layout)

    def test_directory_and_file_links_are_backed_up_without_reading_external_data(self):
        self.add("css", "config:gtk-4.0/gtk.css", "new css")
        self.add("svg", "config:gtk-4.0/assets/icons/a.svg", "new svg")
        external = self.base / "private"
        external.mkdir()
        (external / "key").write_text("private-key-canary")
        gtk = self.config / "gtk-4.0"
        gtk.mkdir(parents=True)
        (gtk / "gtk.css").symlink_to(external / "key")
        (gtk / "assets").symlink_to(external)
        items = dots.plan(self.source, self.layout)
        self.assertEqual([i["action"] for i in items], ["replace-link", "replace-link"])
        transaction = dots.Transaction(self.layout, items)
        transaction.apply()
        self.assertEqual((gtk / "assets/icons/a.svg").read_text(), "new svg")
        self.assertEqual((external / "key").read_text(), "private-key-canary")
        transaction.rollback()
        self.assertEqual((gtk / "assets").readlink(), external)
        self.assertEqual((gtk / "gtk.css").readlink(), external / "key")
        self.assertEqual(list(external.iterdir()), [external / "key"])

    def test_cli_restore_reinstates_old_config_and_removes_new_files(self):
        self.add("a", "config:app/a", "new")
        target = self.config / "app/a"
        target.parent.mkdir(parents=True)
        target.write_text("old")
        self.add("b", "config:app/b", "added")
        transaction = self.install()
        command = [ROOT / "scripts/restore-config", "--destination", self.layout["home"].parent, "--backup", transaction.backup]
        result = subprocess.run([*command, "--dry-run"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(target.read_text(), "new")
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(target.read_text(), "old")
        self.assertFalse((self.config / "app/b").exists())

    def test_repository_catalog_is_complete_and_excludes_local_secrets(self):
        entries = dots.entries(ROOT / "config", self.layout)
        self.assertGreater(len(entries), 100)
        self.assertTrue(all(i["path"].is_relative_to(self.layout["home"].parent) for i in entries))
        self.assertFalse(any(i["path"].name == "whisper.fish" for i in entries))


if __name__ == "__main__":
    unittest.main()
