"""Installer behavior on private files and a real, inert Quickshell IPC fixture."""
import importlib.util
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, call, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import _install as installer
from _common import isolated_environment, stop_process_group


class InstallTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="putkin-install-test-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.layout = installer.paths(self.base / "cel ze spacją ' $ ` ;")
        self.store = self.layout["store"]
        self.source = self.base / "source"
        for directory in (*installer.RUNTIME_DIRS, "scripts", "docs", "tests"):
            (self.source / directory).mkdir(parents=True)
        (self.source / "scripts/lock-session").write_text("#!/usr/bin/env python3\n")
        (self.source / "scripts/ssh-askpass").write_text("#!/usr/bin/env python3\n")
        (self.source / "docs/private.txt").write_text("not runtime")
        (self.source / "settings.json").write_text("private preferences")
        (self.source / "services/__pycache__").mkdir()
        (self.source / "services/__pycache__/ignored.pyc").write_bytes(b"cache")
        self.version(0)

    def version(self, number):
        (self.source / "shell.qml").write_text(f"import Quickshell\nShellRoot {{ property int version: {number} }}\n")
        (self.source / "core/value.js").write_text(f"var version = {number};\n")

    def prepare(self):
        with patch.object(installer, "validate"):
            return installer.prepare(self.store, self.source)

    def test_updates_reuse_identical_builds_keep_five_and_preserve_user_files(self):
        settings = self.layout["entry"].parent.parent / "putkin/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_text('{"accent":"blue"}')
        seen = []
        for i in range(8):
            self.version(i)
            build = self.prepare()
            installer.publish(self.store, build)
            installer.configure(self.layout)
            installer.prune(self.layout)
            seen.append(build)
            self.assertEqual(self.layout["entry"].resolve(), build / "shell.qml")
            self.assertEqual(installer.manifest(build), installer.source_files(self.source))
            self.assertEqual(len(installer.releases(self.store)), min(i + 1, 5))
        self.assertEqual(set(installer.releases(self.store)), set(seen[-5:]))
        self.assertEqual(self.prepare(), seen[-1])
        self.assertEqual(settings.read_text(), '{"accent":"blue"}')
        self.assertFalse((seen[-1] / "docs").exists())
        self.assertFalse((seen[-1] / "settings.json").exists())
        self.assertFalse((seen[-1] / "services/__pycache__").exists())

    def test_restore_toggles_complete_builds(self):
        old = self.prepare()
        installer.publish(self.store, old)
        self.version(1)
        new = self.prepare()
        installer.publish(self.store, new)
        installer.publish(self.store, installer.current(self.store, "previous"))
        self.assertEqual(installer.current(self.store), old)
        self.assertEqual(installer.current(self.store, "previous"), new)
        self.assertEqual((self.store / "current/core/value.js").read_text(), "var version = 0;\n")

    def test_copy_and_validation_failure_leave_old_complete(self):
        old = self.prepare()
        installer.publish(self.store, old)
        self.version(1)
        for operation in ("validate", "shutil.copy2"):
            with self.subTest(operation=operation), patch("_install." + operation, side_effect=OSError("injected failure")):
                with self.assertRaises(OSError):
                    installer.prepare(self.store, self.source)
            self.assertEqual(installer.current(self.store), old)
            installer.verify(old)
            self.assertEqual(installer.releases(self.store), [old])
            self.assertFalse(list((self.store / "releases").glob(".stage-*")))

    def test_corrupted_build_and_source_symlink_are_rejected(self):
        build = self.prepare()
        (build / "core/value.js").write_text("changed")
        with self.assertRaisesRegex(ValueError, "Uszkodzona"):
            installer.publish(self.store, build)
        self.assertIsNone(installer.current(self.store))
        (self.source / "assets/outside").symlink_to(self.base)
        with self.assertRaisesRegex(ValueError, "Dowiązanie"):
            installer.source_files(self.source)

    def test_process_interruption_at_publication_leaves_whole_old_or_new_build(self):
        old = self.prepare()
        installer.publish(self.store, old)
        self.version(1)
        new = self.prepare()
        script = '''
import os, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import _install
real = os.replace
def interrupted(source, target):
    if Path(target).name == "current":
        if sys.argv[4] == "after": real(source, target)
        os._exit(73)
    return real(source, target)
_install.os.replace = interrupted
_install.publish(Path(sys.argv[2]), Path(sys.argv[3]))
'''
        for moment in ("before", "after"):
            installer.atomic_link(self.store / "current", old)
            result = subprocess.run([sys.executable, "-c", script, str(ROOT / "scripts"), str(self.store), str(new), moment])
            self.assertEqual(result.returncode, 73)
            visible = installer.current(self.store)
            self.assertEqual(visible, old if moment == "before" else new)
            installer.verify(visible)

    def test_retention_preserves_current_previous_and_unrelated_state(self):
        builds = []
        for i in range(7):
            self.version(i)
            builds.append(self.prepare())
        installer.publish(self.store, builds[0])
        installer.publish(self.store, builds[1])
        for build in builds:
            (self.layout["state"] / ("update-" + build.name)).mkdir(parents=True)
        unrelated = self.layout["state"] / "launcher.json"
        unrelated.write_text("history")
        outside = self.base / "outside"
        outside.mkdir()
        (outside / "keep").write_text("keep")
        (self.store / "releases/20260101-other-000000000000").symlink_to(outside)
        removed = installer.prune(self.layout)
        self.assertEqual(len(removed), 2)
        self.assertEqual(len(installer.releases(self.store)), 5)
        self.assertTrue(builds[0].exists() and builds[1].exists())
        self.assertTrue((outside / "keep").exists())
        self.assertEqual(unrelated.read_text(), "history")
        for name in removed:
            self.assertFalse((self.layout["state"] / ("update-" + name)).exists())

    def test_default_entry_backup_keeps_existing_helpers(self):
        entry = self.layout["entry"]
        entry.parent.mkdir(parents=True)
        entry.write_text("previous shell")
        (entry.parent / "helper").write_text("independent helper")
        installer.publish(self.store, self.prepare())
        installer.configure(self.layout)
        installer.configure(self.layout)
        self.assertEqual((entry.parent.with_name("quickshell.previous") / "shell.qml").read_text(), "previous shell")
        self.assertEqual((entry.parent.with_name("quickshell.previous") / "helper").read_text(), "independent helper")
        self.assertTrue(os.access(self.layout["launcher"], os.X_OK))

    def test_dry_run_creates_nothing_and_destination_refuses_host_activation(self):
        destination = self.base / "untouched"
        result = subprocess.run([ROOT / "scripts/install", "--dry-run", "--destination", destination], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["keep"], 5)
        self.assertFalse(destination.exists())
        result = subprocess.run([ROOT / "scripts/install", "--destination", destination, "--activate"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(destination.exists())

    def test_real_package_install_and_reinstall(self):
        result = subprocess.run([ROOT / "scripts/install", "--source", self.source, "--destination", self.base / "real package"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        layout = installer.paths(self.base / "real package")
        build = installer.current(layout["store"])
        installer.verify(build)
        self.assertEqual(installer.manifest(build), installer.source_files(self.source))
        result = subprocess.run([ROOT / "scripts/install", "--source", self.source, "--destination", self.base / "real package"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(installer.releases(layout["store"]), [build])

    def test_failed_activation_restores_original_default_and_instance_path(self):
        old = self.prepare()
        installer.publish(self.store, old)
        self.layout["entry"].parent.mkdir(parents=True)
        self.layout["entry"].write_text("previous default")
        self.version(1)
        session = Mock()
        session.old = {"config_path": str(old / "shell.qml")}
        session.old_build = old
        session.start.side_effect = [RuntimeError("failed activation"), {}]
        main = runpy.run_path(str(ROOT / "scripts/install"))["main"]
        with patch.dict(main.__globals__, paths=lambda _: self.layout, dependencies=lambda: {}, Session=lambda _: session), \
                patch.object(installer, "validate"), \
                patch.object(sys, "argv", ["install", "--activate", "--source", str(self.source)]):
            with self.assertRaisesRegex(RuntimeError, "failed activation"):
                main()
        self.assertEqual(installer.current(self.store), old)
        installer.verify(old)
        self.assertEqual(self.layout["entry"].read_text(), "previous default")
        self.assertFalse(self.layout["entry"].parent.is_symlink())
        self.assertFalse(self.layout["launcher"].exists())
        self.assertEqual(session.start.call_args_list, [call(), call(str(old / "shell.qml"))])

    def test_dry_run_existing_install_and_cli_restore(self):
        args = [ROOT / "scripts/install", "--source", self.source, "--destination", self.layout["entry"].parents[2]]
        # Use the exact private layout root (config/quickshell/shell.qml).
        for version in (0, 1):
            self.version(version)
            result = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        old, new = installer.current(self.store, "previous"), installer.current(self.store)
        before = {str(path): installer.file_state(path) for path in self.store.rglob("*") if path.is_file() or path.is_symlink()}
        result = subprocess.run([*args, "--dry-run", "--restore"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        after = {str(path): installer.file_state(path) for path in self.store.rglob("*") if path.is_file() or path.is_symlink()}
        self.assertEqual(before, after)
        result = subprocess.run([*args, "--restore"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(installer.current(self.store), old)
        self.assertEqual(installer.current(self.store, "previous"), new)

    def test_locked_or_foreign_session_cannot_be_stopped(self):
        build = self.prepare()
        session = installer.Session(self.layout)
        own = {"config_path": str(build / "shell.qml"), "id": "fixture", "pid": 42}
        with patch.object(installer, "instances", return_value=[own]), patch.object(installer, "run", return_value="true") as run:
            with self.assertRaisesRegex(RuntimeError, "zablokowana"):
                session.preflight()
            self.assertEqual(run.call_args_list, [unittest.mock.call(["hyprctl", "locked"])])
        with patch.object(installer, "instances", return_value=[dict(own, config_path="/other/shell.qml")]), patch.object(installer, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "inna konfiguracja"):
                session.preflight()
            run.assert_not_called()


class DefaultQuickshellTest(unittest.TestCase):
    def test_default_symlink_relative_imports_duplicate_and_pointer_switch(self):
        with tempfile.TemporaryDirectory(prefix="pk-default-") as directory:
            base = Path(directory)
            env = isolated_environment(directory)
            config = Path(env["XDG_CONFIG_HOME"]) / "quickshell"
            for version in ("one", "two"):
                build = base / version
                (build / "local").mkdir(parents=True)
                (build / "local/Value.qml").write_text('import QtQml\nQtObject { readonly property string value: "' + version + '" }\n')
                (build / "shell.qml").write_text('import Quickshell\nimport Quickshell.Io\nimport "local"\n'
                    'ShellRoot { Value { id: v } IpcHandler { target: "probe"; function version(): string { return v.value; } } }\n')
            installer.atomic_link(base / "current", base / "one")
            installer.atomic_link(config, base / "current")
            with (base / "qs.log").open("w+") as log:
                process = subprocess.Popen(["dbus-run-session", "--", "quickshell", "--no-color", "--no-duplicate"],
                                           env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                def ipc(*selection):
                    return subprocess.run(["quickshell", "ipc", *selection, "call", "probe", "version"], env=env, capture_output=True, text=True)
                try:
                    for _ in range(100):
                        response = ipc()
                        if response.returncode == 0 or process.poll() is not None:
                            break
                        time.sleep(.05)
                    log.flush()
                    details = os.pread(log.fileno(), 100000, 0).decode()
                    self.assertEqual(response.returncode, 0, details + response.stdout + response.stderr)
                    self.assertEqual(response.stdout.strip(), "one")
                    instances = json.loads(subprocess.check_output(["quickshell", "list", "--all", "--json"], env=env, text=True))
                    self.assertEqual(len(instances), 1)
                    self.assertEqual(instances[0]["config_path"], str(config / "shell.qml"))
                    duplicate = subprocess.run(["quickshell", "--no-duplicate"], env=env, capture_output=True, text=True, timeout=5)
                    self.assertEqual(duplicate.returncode, 0, duplicate.stderr)
                    installer.atomic_link(base / "current", base / "two")
                    time.sleep(.2)
                    self.assertEqual(ipc("--id", instances[0]["id"]).stdout.strip(), "one")
                    self.assertEqual(ipc().stdout.strip(), "one")
                finally:
                    stop_process_group(process)


class LauncherTest(unittest.TestCase):
    def test_lock_helper_uses_stable_config_identity(self):
        with tempfile.TemporaryDirectory(prefix="putkin-lock-path-") as directory:
            base = Path(directory)
            env = isolated_environment(directory)
            build = base / "build"
            (build / "scripts").mkdir(parents=True)
            shutil.copy2(ROOT / "scripts/lock-session", build / "scripts/lock-session")
            config = Path(env["XDG_CONFIG_HOME"]) / "quickshell"
            config.symlink_to(build)
            binary = base / "bin"
            binary.mkdir()
            (binary / "quickshell").write_text('#!/usr/bin/env python3\nimport json,sys\nfrom pathlib import Path\n'
                'Path(sys.argv[3]).with_name("called.json").write_text(json.dumps(sys.argv[1:]))\nprint("accepted")\n')
            (binary / "quickshell").chmod(0o755)
            env["PATH"] = str(binary) + ":/usr/bin"
            result = subprocess.run([sys.executable, config / "scripts/lock-session"], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads((build / "called.json").read_text()),
                             ["ipc", "--path", str(config / "shell.qml"), "call", "session", "lock"])

    def test_bare_qs_uses_uwsm_and_forwards_cli_queries_without_shell_interpolation(self):
        with tempfile.TemporaryDirectory(prefix="putkin-launch-test-") as directory:
            base = Path(directory)
            env = isolated_environment(directory)
            binary = base / "bin"
            binary.mkdir()
            record = base / "calls.jsonl"
            fake = '#!/usr/bin/env python3\nimport json,os,sys\nfrom pathlib import Path\n' \
                   'with open(os.environ["CALLS"],"a") as f: f.write(json.dumps([Path(sys.argv[0]).name,*sys.argv[1:]])+"\\n")\n' \
                   'if Path(sys.argv[0]).name == "quickshell" and sys.argv[1:] == ["list","--all","--json"]: print(os.environ.get("INSTANCES","No running instances."))\n'
            for name in ("uwsm", "quickshell", "systemctl"):
                (binary / name).write_text(fake)
                (binary / name).chmod(0o755)
            config = Path(env["XDG_CONFIG_HOME"])
            (config / "quickshell").mkdir()
            (config / "quickshell/shell.qml").write_text("fixture")
            (config / "putkin").mkdir()
            wallpaper = str(base / "a '$HOME `id` image.png")
            (config / "putkin/launch.json").write_text(json.dumps({"wallpaper": wallpaper}))
            env.update(PATH=str(binary) + ":/usr/bin", CALLS=str(record))
            result = subprocess.run([ROOT / "scripts/qs"], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = [json.loads(line) for line in record.read_text().splitlines()]
            self.assertEqual(calls[1][:10], ["uwsm", "app", "-s", "s", "-t", "service", "-u", "putkin.service", "--", "env"])
            self.assertIn("PUTKIN_WALLPAPER=" + wallpaper, calls[1])
            self.assertEqual(calls[1][-2:], [str(binary / "quickshell"), "--no-duplicate"])
            self.assertNotIn("--daemonize", calls[1])
            record.unlink()
            subprocess.run([ROOT / "scripts/qs", "ipc", "call", "probe", "value", "a b; $HOME"], env=env, check=True)
            self.assertEqual(json.loads(record.read_text()), ["quickshell", "ipc", "call", "probe", "value", "a b; $HOME"])
            record.unlink()
            env["INSTANCES"] = json.dumps([{"pid": 42, "config_path": str(config / "quickshell/shell.qml")}])
            subprocess.run([ROOT / "scripts/qs"], env=env, check=True)
            self.assertEqual(len(record.read_text().splitlines()), 1)


class SessionReadinessTest(unittest.TestCase):
    def start_with_owners(self, responses):
        layout = installer.paths(Path('/unused-private-install-test'))
        instance = {'pid': 42, 'id': 'fixture', 'config_path': str(layout['entry'])}
        responses = iter(responses)

        def run(command, check=True):
            if command[0] == layout['launcher']:
                return ''
            if command[0] == 'busctl':
                self.assertFalse(check)
                return next(responses)
            if command[:2] == ['quickshell', 'log']:
                return 'INFO: Configuration Loaded'
            if command[0] == 'quickshell' and 'session' in command:
                return json.dumps({'idle': {'ready': True}, 'capabilities': {'lock': {'available': True}}})
            if command[0] == 'quickshell' and 'caffeinate' in command:
                return json.dumps({'busy': False, 'mode': 'off', 'error': ''})
            raise AssertionError(command)

        with patch.object(installer, 'run', side_effect=run) as runner, \
                patch.object(installer, 'instances', return_value=[instance]), \
                patch.object(installer.time, 'sleep'):
            result = installer.Session(layout).start()
            calls = [call for call in runner.call_args_list if call.args[0][0] == 'busctl']
        return result, len(calls)

    def test_waits_for_notification_name_after_lock_service_is_ready(self):
        result, queries = self.start_with_owners(['', '', json.dumps({'data': [42]})])
        self.assertEqual(result['pid'], 42)
        self.assertEqual(queries, 3)

    def test_existing_foreign_notification_owner_still_aborts(self):
        with self.assertRaisesRegex(RuntimeError, 'Konflikt instancji'):
            self.start_with_owners([json.dumps({'data': [99]})])


if __name__ == "__main__":
    unittest.main()
