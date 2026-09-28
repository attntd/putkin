"""Runtime selection rejects tampering before any native program is started."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "services"))
from signal_call_runtime import verify, resolve


class CallRuntimeTests(unittest.TestCase):
    def test_only_pinned_executable_is_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            policy = source / "services/signal-call-tunnel"
            policy.mkdir(parents=True)
            pin = {"format": 1, "commit": "test-pin"}
            (policy / "runtime.json").write_text(json.dumps(pin))
            bundle = source / "dependencies/signal-calls"
            (bundle / "bin").mkdir(parents=True)
            binary = bundle / "bin/signal-call-tunnel"
            binary.write_bytes(b"synthetic; never execute")
            binary.chmod(0o700)
            manifest = bundle / "manifest.json"
            record = {"format": 1, "source": pin, "sha256": hashlib.sha256(binary.read_bytes()).hexdigest()}
            manifest.write_text(json.dumps(record))
            self.assertEqual(verify(bundle, source), binary)
            self.assertEqual(resolve(source), str(binary))
            binary.chmod(0o600)
            self.assertIsNone(resolve(source))
            binary.chmod(0o700)
            binary.write_bytes(b"tampered")
            self.assertIsNone(resolve(source))
            binary.unlink()
            binary.symlink_to(source / "missing")
            self.assertIsNone(resolve(source))
            manifest.write_text("[]")
            self.assertIsNone(resolve(source))
            manifest.write_text(json.dumps(dict(record, source={"commit": "wrong"})))
            self.assertIsNone(resolve(source))


if __name__ == "__main__":
    unittest.main()
