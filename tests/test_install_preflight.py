"""Real native import/config gates; no production instances, hardware or PAM."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import _preflight
from _dotfiles import plan
from _install import paths


class PreflightTests(unittest.TestCase):
    def test_real_production_imports_and_modular_hyprland_pass_without_writes(self):
        with tempfile.TemporaryDirectory(prefix="pk-preflight-") as directory:
            layout = paths(Path(directory) / "untouched")
            _preflight.compile_runtime(ROOT)
            _preflight.validate_hyprland(plan(ROOT / "config", layout), layout, ROOT)
            self.assertFalse(layout["home"].parent.exists())

    def test_real_missing_native_module_is_a_failure(self):
        with tempfile.TemporaryDirectory(prefix="pk-missing-import-") as directory:
            source = Path(directory)
            (source / "shell.qml").write_text("import Quickshell\nimport PutkinMissingNativeModule\nShellRoot {}\n")
            with self.assertRaisesRegex(RuntimeError, "PutkinMissingNativeModule"):
                _preflight.compile_runtime(source)

    def test_invalid_hyprland_config_is_rejected_before_target_exists(self):
        with tempfile.TemporaryDirectory(prefix="pk-invalid-hypr-") as directory:
            layout = paths(Path(directory) / "untouched")
            item = {"path": layout["entry"].parent.parent / "hypr/hyprland.lua",
                    "data": b"local broken = {\n", "action": "install"}
            with self.assertRaisesRegex(RuntimeError, "Nieprawidłowa konfiguracja"):
                _preflight.validate_hyprland([item], layout, ROOT)
            self.assertFalse(layout["home"].parent.exists())

    def test_old_quickshell_is_rejected_with_detected_and_required_versions(self):
        original = _preflight.version
        with patch.object(_preflight, "version", side_effect=lambda command:
                          "Quickshell 0.2.0" if command[0] == "quickshell" else original(command)):
            with self.assertRaisesRegex(RuntimeError, "0.3.1.*0.2.0"):
                _preflight.dependencies()


if __name__ == "__main__":
    unittest.main()
