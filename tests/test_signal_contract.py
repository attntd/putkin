"""Executable S00 transport examples, not a test of Signal synchronization."""

import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from signal_cli_fake import replay


ROOT = Path(__file__).resolve().parents[1]
SCENARIO = ROOT / "tests/fixtures/signal/v0.14.8/session.json"


class SignalContractTest(unittest.TestCase):
    def setUp(self):
        self.fixture = json.loads(SCENARIO.read_text())
        self.requests = [{"jsonrpc": "2.0", "id": f"request-ą-{i}", "method": step["method"],
                          "params": step.get("params", {})}
                         for i, step in enumerate(self.fixture["exchanges"])]
        self.payload = ("\n".join(json.dumps(r, ensure_ascii=False) for r in self.requests) + "\n").encode()

    def test_stdio_round_trip_and_eof(self):
        with tempfile.TemporaryDirectory(prefix="signal-contract-") as directory:
            env = {"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"}
            for kind in ("CONFIG", "DATA", "STATE", "CACHE", "RUNTIME"):
                path = Path(directory) / kind.lower()
                path.mkdir(mode=0o700)
                env[f"XDG_{kind}_{'DIR' if kind == 'RUNTIME' else 'HOME'}"] = str(path)
            result = subprocess.run([sys.executable, "-B", str(ROOT / "tests/signal_cli_fake.py"),
                                     "--scenario", str(SCENARIO), "--chunk-bytes", "1"],
                                    input=self.payload, capture_output=True, env=env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertEqual(result.stderr, b"")
        frames = [json.loads(line) for line in result.stdout.splitlines()]
        replies = [frame for frame in frames if "id" in frame]
        self.assertEqual([frame["id"] for frame in replies], [r["id"] for r in self.requests])
        for reply, step in zip(replies, self.fixture["exchanges"]):
            key = "error" if "error" in step else "result"
            self.assertEqual(reply[key], step[key])
        events = [frame for frame in frames if "id" not in frame]
        self.assertEqual(events, [event["wire"] for event in self.fixture["events"]])
        self.assertLess(frames.index(events[0]), frames.index(replies[1]))
        envelope = events[0]["params"]["result"]["envelope"]
        self.assertEqual(envelope["dataMessage"]["message"], "Zażółć gęślą jaźń 👋\ndruga linia")
        self.assertEqual(envelope["dataMessage"]["timestamp"], 1790000000000)

    def test_byte_fragmentation_preserves_multibyte_utf8(self):
        class Writes(io.BytesIO):
            sizes = []

            def write(self, data):
                self.sizes.append(len(data))
                return super().write(data)

        chunks = Writes()
        replay(self.fixture, io.BytesIO(self.payload), chunks, 1)
        normal = io.BytesIO()
        replay(self.fixture, io.BytesIO(self.payload), normal)
        self.assertTrue(chunks.sizes)
        self.assertEqual(set(chunks.sizes), {1})
        self.assertEqual(chunks.getvalue(), normal.getvalue())

    def test_manual_receive_waits_for_subscription_request(self):
        output = io.BytesIO()
        first = json.dumps(self.requests[0]).encode() + b"\n"
        with self.assertRaisesRegex(ValueError, "EOF"):
            replay(self.fixture, io.BytesIO(first), output)
        self.assertEqual(json.loads(output.getvalue()),
                         {"jsonrpc": "2.0", "id": self.requests[0]["id"],
                          "result": self.fixture["exchanges"][0]["result"]})

    def test_wrong_recipient_cannot_get_scripted_send_success(self):
        self.requests[2]["params"] = dict(self.requests[2]["params"], recipient=["unexpected"])
        payload = ("\n".join(json.dumps(r) for r in self.requests) + "\n").encode()
        output = io.BytesIO()
        with self.assertRaisesRegex(ValueError, "match"):
            replay(self.fixture, io.BytesIO(payload), output)
        self.assertNotIn(self.requests[2]["id"], output.getvalue().decode())

    def test_malformed_truncated_and_oversized_input_fail(self):
        for payload in (b"{broken}\n", b"{}", b"[]\n", b"x" * (1024 * 1024 + 1)):
            with self.subTest(length=len(payload)), self.assertRaises(ValueError):
                replay(self.fixture, io.BytesIO(payload), io.BytesIO())


if __name__ == "__main__":
    unittest.main()
