import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("night_light", ROOT / "services/night_light.py")
night = importlib.util.module_from_spec(spec)
spec.loader.exec_module(night)


class NightLightOwner(unittest.TestCase):
    def inspect(self, version="hyprsunset v0.4.0", state="active", pid=42):
        results = [subprocess.CompletedProcess([], 0, f"MainPID={pid}\nActiveState={state}\n", ""),
                   subprocess.CompletedProcess([], 0, version, "")]
        with patch.object(night.shutil, "which", return_value="/usr/bin/hyprsunset"), \
             patch.object(night.os.path, "samefile", return_value=True), \
             patch.object(night.subprocess, "run", side_effect=results) as runner:
            night.inspect_owner(42)
            self.assertEqual(runner.call_args_list[0].args[0],
                             ["systemctl", "--user", "show", "hyprsunset.service", "--property=MainPID", "--property=ActiveState"])
            self.assertEqual(runner.call_args_list[1].args[0], ["/usr/bin/hyprsunset", "--version"])

    def test_current_version_and_active_owner(self):
        self.inspect()

    def test_old_version_is_rejected_before_ipc(self):
        with self.assertRaisesRegex(night.Unavailable, "version"):
            self.inspect(version="hyprsunset v0.3.3")

    def test_unknown_version_is_rejected(self):
        with self.assertRaisesRegex(night.Unavailable, "version"):
            self.inspect(version="hyprsunset v0.5.0")

    def test_foreign_or_inactive_unit(self):
        for state, pid in [("inactive", 42), ("active", 43), ("activating", 42)]:
            with self.subTest(state=state, pid=pid), self.assertRaisesRegex(night.Unavailable, "service"):
                self.inspect(state=state, pid=pid)

    def test_foreign_executable_is_never_run(self):
        with patch.object(night.shutil, "which", return_value="/usr/bin/hyprsunset"), \
             patch.object(night.os.path, "samefile", return_value=False), \
             patch.object(night.subprocess, "run") as runner:
            with self.assertRaisesRegex(night.Unavailable, "owner"):
                night.inspect_owner(os.getpid())
            runner.assert_not_called()

    def test_process_token_and_session_scope(self):
        self.assertRegex(night.process_token(os.getpid()), rf"^{os.getpid()}:[0-9]+$")
        with patch.dict(os.environ, {"XDG_RUNTIME_DIR": "/tmp/private", "HYPRLAND_INSTANCE_SIGNATURE": "test_123"}):
            self.assertEqual(str(night.socket_path()), "/tmp/private/hypr/test_123/.hyprsunset.sock")
        with patch.dict(os.environ, {"HYPRLAND_INSTANCE_SIGNATURE": "../../other"}):
            self.assertEqual(night.run(["read"])["error"], "session")

    def test_invalid_arguments_do_not_connect(self):
        client = night.Client("/not-used")
        for arguments in [["start"], ["set", "1:2", "on", "999"], ["set", "1:2", "on", "6501"],
                          ["set", "1:2", "toggle", "4500"], ["set", "injection", "on", "4500"]]:
            with self.subTest(arguments=arguments):
                self.assertEqual(night.run(arguments, client)["error"], "input")

    def test_missing_backend_is_structured(self):
        with tempfile.TemporaryDirectory(prefix="pk-") as directory:
            self.assertEqual(night.run(["read"], night.Client(Path(directory) / "absent.sock"))["error"], "absent")
