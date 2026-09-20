"""Exercise the actual gate on temporary files, never mutate project sources."""

from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class CheckGate(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="putkin-gate-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)

    def write(self, name, source):
        path = self.directory / name
        path.write_text(source)
        return path

    def run_gate(self, *args, env=None):
        return subprocess.run([sys.executable, str(ROOT / "scripts/check"), *map(str, args or [self.directory])],
                              capture_output=True, text=True, timeout=30, env=env)

    def test_valid_file_with_spaces_passes_without_modification(self):
        source = "import QtQuick\nItem { property int answer: 42 }\n"
        path = self.write("Valid sample.qml", source)
        result = self.run_gate(path)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(path.read_text(), source)

    def test_bad_syntax_fails(self):
        path = self.write("Broken.qml", "import QtQuick\nItem { property int broken: }\n")
        result = self.run_gate(path)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("FAIL [syntax", result.stderr)

    def test_missing_import_fails(self):
        path = self.write("Missing.qml", "import QtQuick\nimport Putkin.DoesNotExist\nItem {}\n")
        result = self.run_gate(path)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("FAIL [imports/types", result.stderr)

    def test_all_files_are_checked_even_after_failures(self):
        self.write("A.qml", "import QtQuick\nItem { property int broken: }\n")
        self.write("B.qml", "import QtQuick\nimport Putkin.DoesNotExist\nItem {}\n")
        self.write("Z.qml", "import QtQuick\nItem {}\n")
        result = self.run_gate()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("3 plików QML, 2 z błędami", result.stdout)
        self.assertIn("A.qml", result.stderr)
        self.assertIn("B.qml", result.stderr)

    def test_missing_tools_are_distinct_from_qml_failure(self):
        self.write("Valid.qml", "import QtQuick\nItem {}\n")
        for name in ["QMLFORMAT", "QMLLINT"]:
            with self.subTest(tool=name):
                env = dict(os.environ, **{f"PUTKIN_{name}": str(self.directory / "absent-tool")})
                result = self.run_gate(env=env)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertNotIn("PASS", result.stdout)

    def test_empty_or_missing_input_fails(self):
        self.assertEqual(self.run_gate().returncode, 2)
        self.assertEqual(self.run_gate(self.directory / "absent.qml").returncode, 2)


if __name__ == "__main__":
    unittest.main()
