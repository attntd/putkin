"""Negative runtime tests: each CLI must expose a genuine QML load failure."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from _common import ROOT, ipc_json, runtime_log


class RuntimeDiagnostics(unittest.TestCase):
    def test_log_reader_preserves_child_offset(self):
        with tempfile.TemporaryFile(mode="w+") as log:
            log.write("first\n"); log.flush()
            before = log.tell()
            self.assertEqual(runtime_log(log), "first\n")
            self.assertEqual(log.tell(), before)
            log.write("second\n"); log.flush()
            self.assertEqual(runtime_log(log), "first\nsecond\n")

    def test_only_absent_startup_reply_is_retryable(self):
        self.assertEqual(ipc_json(""), {})
        self.assertEqual(ipc_json('{"ready":false}'), {"ready": False})
        for value in ["No running instances", "{", "null", "[]"]:
            with self.subTest(value=value), self.assertRaises(AssertionError):
                ipc_json(value)

    def test_clis_report_missing_qml_import(self):
        # Copy only runtime/test inputs; never corrupt the working tree or load
        # production adapters. Every entrypoint is replaced before any launch.
        with tempfile.TemporaryDirectory(prefix="pk-broken-") as directory:
            project = Path(directory)
            for name in ["scripts", "services", "config"]:
                shutil.copytree(ROOT / name, project / name, ignore=shutil.ignore_patterns("__pycache__"))
            (project / "tests").mkdir()
            shutil.copytree(ROOT / "tests/fixtures", project / "tests/fixtures")
            for file in (ROOT / "tests").glob("*.py"):
                if not file.name.startswith("test_"):
                    shutil.copy2(file, project / "tests" / file.name)
            shutil.copy2(ROOT / "tests/pipewire.conf", project / "tests/pipewire.conf")
            broken = "import QtQuick\nimport Putkin.DeliberatelyMissingValidationModule\nItem {}\n"
            for file in ROOT.glob("*.qml"):
                (project / file.name).write_text(broken)
            (project / "tests/qml").mkdir()
            (project / "tests/qml/tst_broken.qml").write_text(broken)
            commands = [[str(path)] for path in sorted((project / "scripts").glob("test-*-integration"))]
            commands += [[str(project / "scripts/preview")], [str(project / "scripts/measure-idle")],
                         [str(project / "scripts/test")]]
            for command in commands:
                with self.subTest(command=Path(command[0]).name):
                    result = subprocess.run([sys.executable, *command], cwd=project,
                                            capture_output=True, text=True, timeout=25)
                    output = result.stdout + result.stderr
                    self.assertNotEqual(result.returncode, 0, output)
                    self.assertIn("Putkin.DeliberatelyMissingValidationModule", output)
                    self.assertIn("is not installed", output)
                    self.assertNotIn("JSONDecodeError", output)
                    self.assertNotIn("entrypoint ready: {}", output)


if __name__ == "__main__":
    unittest.main()
