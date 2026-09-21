"""Assuan behavior with fake UI; no GPG agent, host bus, PAM or key material."""
import io
from pathlib import Path
import sys
import unittest
from urllib.parse import unquote

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "services"))
import pinentry
from auth_client import Cancelled


class PinentryTests(unittest.TestCase):
    def run_protocol(self, script, replies):
        requests = []
        def ask(payload, timeout):
            requests.append((payload, timeout))
            result = replies.pop(0)
            if isinstance(result, Exception):
                raise result
            return result
        output = io.StringIO()
        pinentry.run(io.StringIO(script), output, ask)
        return output.getvalue().splitlines(), requests

    def test_unicode_percent_newlines_and_bounded_data(self):
        secret = ("żółć%\n" * 80)
        lines, requests = self.run_protocol("SETDESC Klucz%0A%25test\nSETPROMPT PIN:\nGETPIN\nBYE\n",
                                           [{"accepted": True, "response": secret}])
        self.assertEqual(requests[0][0]["message"], "Klucz\n%test")
        self.assertEqual("".join(unquote(line[2:]) for line in lines if line.startswith("D ")), secret)
        self.assertTrue(all(len(line.encode()) < 1000 for line in lines))

    def test_error_reset_timeout_and_no_secrets_in_request(self):
        lines, requests = self.run_protocol("SETERROR Bad PIN\nSETTIMEOUT 5\nGETPIN\nGETPIN\nBYE\n",
            [{"accepted": True, "response": "fixture"}, {"accepted": True, "response": "other"}])
        self.assertEqual(requests[0][0]["error"], "Bad PIN")
        self.assertEqual(requests[1][0]["error"], "")
        self.assertEqual(requests[0][1], 5)
        self.assertNotIn("fixture", str(requests))
        self.assertEqual(lines[-1], "OK")

    def test_confirmation_reject_cancel_and_one_button(self):
        lines, requests = self.run_protocol("CONFIRM\nCONFIRM\nCONFIRM --one-button\nMESSAGE\nBYE\n",
            [{"accepted": False, "response": "", "rejected": True}, Cancelled(),
             {"accepted": True, "response": ""}, {"accepted": True, "response": ""}])
        self.assertIn(pinentry.NOT_CONFIRMED, lines)
        self.assertIn(pinentry.CANCELLED, lines)
        self.assertEqual([r[0]["mode"] for r in requests], ["confirm", "confirm", "message", "message"])
        self.assertFalse(any(line.startswith("D ") for line in lines))

    def test_required_new_password_constraints_never_silently_ignored(self):
        for setup in ("SETREPEAT Again", "OPTION constraints-enforce", "OPTION formatted-passphrase"):
            with self.subTest(setup=setup):
                lines, requests = self.run_protocol(setup + "\nGETPIN\nRESET\nGETPIN\nBYE\n",
                    [{"accepted": True, "response": "existing"}])
                self.assertEqual(lines.count(pinentry.UNSUPPORTED), 2)
                self.assertEqual(len(requests), 1)

    def test_unknown_invalid_and_eof(self):
        lines, requests = self.run_protocol("UNKNOWN\nSETTIMEOUT -1\nSETDESC %00\nCONFIRM --bogus\n", [])
        self.assertIn(pinentry.UNKNOWN, lines)
        self.assertEqual(lines.count(pinentry.PARAMETER), 2)
        self.assertEqual(requests, [])

    def test_explicit_button_semantics(self):
        _, requests = self.run_protocol("SETOK _Allow\nSETNOTOK Deny__once\nCONFIRM\n",
            [{"accepted": True, "response": ""}])
        self.assertEqual(requests[0][0]["accept"], "Allow")
        self.assertEqual(requests[0][0]["reject"], "Deny_once")


if __name__ == "__main__":
    unittest.main()
