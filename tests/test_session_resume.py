"""Resume event ordering with injected functions; no buses, PAM or hardware."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "services"))
from session_backend import SessionBackend


class SessionResumeTests(unittest.TestCase):
    def setUp(self):
        self.events = []
        self.backend = SessionBackend.__new__(SessionBackend)
        self.backend.sleeping = True
        self.backend.login_owner = ":1.42"
        self.backend.emit = self.events.append

    def test_clock_event_precedes_discovery_and_authentication_waits(self):
        def discover():
            self.assertEqual(self.events, [{"resumed": True}])
            self.assertFalse(self.backend.sleeping)
            self.events.append({"fingerprint": True})
        self.backend.refresh = discover
        self.backend.prepare_sleep(False, sender=":1.42")
        self.assertEqual(self.events, [{"resumed": True}, {"fingerprint": True}, {"hold": False}])

    def test_spoofed_and_duplicate_resume_do_not_restart_authentication(self):
        self.backend.refresh = lambda: self.events.append({"discovered": True})
        self.backend.prepare_sleep(False, sender=":1.99")
        self.assertTrue(self.backend.sleeping)
        self.assertEqual(self.events, [])
        self.backend.prepare_sleep(False, sender=":1.42")
        events = list(self.events)
        self.backend.prepare_sleep(False, sender=":1.42")
        self.assertEqual(self.events, events)


if __name__ == "__main__":
    unittest.main()
