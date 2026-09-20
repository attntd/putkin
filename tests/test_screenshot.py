"""Screenshot pixels, geometry, save/clipboard lifetime and process cleanup."""
import importlib.util
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile
import time
import unittest
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("screenshot_backend", ROOT / "services/screenshot_backend.py")
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


class ScreenshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="pk-screenshot-")
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"; self.bin.mkdir()
        for name in ("grim", "hyprctl", "wl-copy"):
            path = self.bin / name
            path.write_bytes((ROOT / "tests/screenshot_tools.py").read_bytes()); path.chmod(0o700)
        self.env = {"PATH": str(self.bin), "XDG_RUNTIME_DIR": str(self.root), "PUTKIN_SCREENSHOT_FIXTURE": str(self.root)}
        self.monitors = [{"name": "TEST", "x": -1600, "y": 100, "width": 2000, "height": 1000, "scale": 1.25,
                          "activeWorkspace": {"id": 1}, "transform": 0}]
        self.clients = [{"address": "0x123", "at": [-1500, 180], "size": [400, 200], "mapped": True,
                         "hidden": False, "workspace": {"id": 1}}]
        self.config = {"monitors": self.monitors, "clients": self.clients}
        self.request = {"mode": "screen", "screen": "TEST", "window": "123", "pictures": str(self.root / "Obrazy ze spacją")}
        self.process = None

    def tearDown(self):
        if self.process:
            if self.process.poll() is None:
                self.process.terminate(); self.process.wait(timeout=3)
            self.process.stdin.close(); self.process.stdout.close(); self.process.stderr.close()
        self.temp.cleanup()

    def start(self, send=True):
        (self.root / "fixture.json").write_text(json.dumps(self.config))
        self.process = subprocess.Popen([sys.executable, str(ROOT / "services/screenshot_backend.py")], env=self.env,
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if send:
            self.send(self.request)

    def send(self, message):
        self.process.stdin.write(json.dumps(message) + "\n"); self.process.stdin.flush()

    def read(self):
        with selectors.DefaultSelector() as selector:
            selector.register(self.process.stdout, selectors.EVENT_READ)
            self.assertTrue(selector.select(timeout=5), "helper did not respond")
        line = self.process.stdout.readline()
        self.assertTrue(line, self.process.stderr.read() if self.process.poll() is not None else "closed stdout")
        return json.loads(line)

    def source(self, result):
        return Path(unquote(urlparse(result["source"]).path))

    def test_no_work_until_request_and_cancel_keeps_clipboard(self):
        self.start(send=False)
        time.sleep(.08)
        self.assertFalse((self.root / "calls").exists())
        self.assertFalse(list(self.root.glob("putkin-screenshot-*")))
        self.send(self.request); result = self.read()
        self.assertEqual((result["width"], result["height"]), (2000, 1000))
        path = self.source(result); image = path.read_bytes()
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(path.parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.root / "clipboard").read_bytes(), image)
        self.process.stdin.close(); self.process.wait(timeout=3)
        self.assertFalse(path.exists())
        self.assertEqual((self.root / "clipboard").read_bytes(), image)
        self.assertFalse(Path(self.request["pictures"]).exists())

    def test_region_save_has_identical_bytes_unique_names_and_cleanup(self):
        self.request.update(mode="region", region=[100, 80, 400, 200])
        self.start(); result = self.read(); path = self.source(result)
        self.assertEqual((result["width"], result["height"]), (500, 250))
        data = path.read_bytes(); saves = []
        for _ in range(2):
            self.send({"op": "save"}); saved = self.read(); saves.append(Path(saved["path"]))
            self.assertEqual(saves[-1].read_bytes(), data)
            self.assertEqual(saves[-1].stat().st_mode & 0o777, 0o600)
        self.assertNotEqual(saves[0], saves[1])
        self.process.terminate(); self.process.wait(timeout=3)
        self.assertFalse(path.exists()); self.assertTrue(saves[0].exists())

    def test_failed_save_keeps_preview_for_retry(self):
        pictures = Path(self.request["pictures"]); pictures.write_text("occupied")
        self.start(); path = self.source(self.read())
        self.send({"op": "save"}); self.assertEqual(self.read()["type"], "error")
        self.assertTrue(path.exists()); pictures.unlink()
        self.send({"op": "save"}); self.assertEqual(self.read()["type"], "saved")

    def test_capture_failure_does_not_replace_clipboard_or_leave_file(self):
        self.config["captureError"] = True
        self.start(); self.assertEqual(self.read()["type"], "error"); self.process.wait(timeout=3)
        self.assertFalse((self.root / "clipboard").exists())
        self.assertFalse(list(self.root.glob("putkin-screenshot-*")))

    def test_clipboard_failure_keeps_savable_png(self):
        self.config["clipboardError"] = True
        self.start(); result = self.read()
        self.assertEqual(result["type"], "captured"); self.assertTrue(result["error"])
        self.send({"op": "save"}); self.assertTrue(Path(self.read()["path"]).exists())

    def test_cancel_during_grim_reaps_child_and_removes_temporary_data(self):
        self.config["slow"] = True; self.start()
        deadline = time.monotonic() + 3
        while not (self.root / "grim.pid").exists() and time.monotonic() < deadline:
            time.sleep(.01)
        pid = int((self.root / "grim.pid").read_text())
        self.process.terminate(); self.process.wait(timeout=3)
        with self.assertRaises(ProcessLookupError): os.kill(pid, 0)
        self.assertFalse(list(self.root.glob("putkin-screenshot-*")))
        self.assertFalse((self.root / "clipboard").exists())

    def test_window_uses_original_address_and_rejects_hidden_or_closed(self):
        self.request["mode"] = "window"
        self.assertEqual(backend.geometry(self.request, self.monitors, self.clients), ("-1500,180 400x200", 1.25))
        for clients in ([], [dict(self.clients[0], hidden=True)], [dict(self.clients[0], workspace={"id": 2})]):
            with self.assertRaises(ValueError): backend.geometry(self.request, self.monitors, clients)

    def test_rotated_fractional_negative_output_and_clipped_region(self):
        rotated = [dict(self.monitors[0], transform=1)]
        self.assertEqual(backend.geometry(self.request, rotated, []), ("-1600,100 800x1600", 1.25))
        self.request.update(mode="region", region=[-10.3, -5.5, 110.3, 55.5])
        self.assertEqual(backend.geometry(self.request, rotated, []), ("-1600,100 100x50", 1.25))

    def test_window_crossing_monitors_keeps_both_visible_parts(self):
        monitors = self.monitors + [dict(self.monitors[0], name="SECOND", x=0, width=1600, height=1200, scale=2)]
        clients = [dict(self.clients[0], at=[-200, 200], size=[600, 300])]
        self.request["mode"] = "window"
        self.assertEqual(backend.geometry(self.request, monitors, clients), ("-200,200 600x300", 2))


if __name__ == "__main__":
    unittest.main()
