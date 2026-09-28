import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

module = runpy.run_path('/home/attntd/.local/bin/update-notifier')
notify = module['notify_updates']
main = module['main']
scan = module['scan']

def result(lines=(), error=None):
    return {'count': len(lines), 'updates': list(lines), 'error': error, 'checked_at': 100}

def results(repo=(), aur=()):
    return {'repo': result(repo), 'aur': result(aur)}

class Notifications(unittest.TestCase):
    def test_no_updates_is_silent(self):
        with patch('subprocess.run') as send:
            self.assertEqual(notify(results(), {}), [])
            send.assert_not_called()

    def test_first_update_and_repeat(self):
        with patch('subprocess.run') as send:
            values = results(['a 1 -> 2'], ['b 2 -> 3'])
            known = notify(values, {})
            self.assertEqual(send.call_count, 1)
            self.assertIn('Dostępne aktualizacje: 2', send.call_args.args[0])
            notify(values, {'notified': known})
            self.assertEqual(send.call_count, 1)

    def test_subset_installed_does_not_notify_again(self):
        with patch('subprocess.run') as send:
            known = notify(results(['a 1 -> 2', 'b 1 -> 2']), {})
            remaining = notify(results(['b 1 -> 2']), {'notified': known})
            self.assertEqual(send.call_count, 1)
            self.assertEqual(remaining, ['repo:b:2'])

    def test_new_target_with_same_count_notifies(self):
        with patch('subprocess.run') as send:
            known = notify(results(['a 1 -> 2']), {})
            notify(results(['a 1 -> 3']), {'notified': known})
            self.assertEqual(send.call_count, 2)

    def test_failed_source_keeps_last_successful_result(self):
        previous = result(['b 1 -> 2'])
        with patch('subprocess.run', return_value=subprocess.CompletedProcess([], 1, '', 'network unavailable')):
            actual = scan(['paru'], {}, previous, 200)
        self.assertEqual(actual['updates'], previous['updates'])
        self.assertEqual(actual['checked_at'], 100)
        self.assertIn('network unavailable', actual['error'])

    def test_checkupdates_empty_exit_two_is_success(self):
        with patch('subprocess.run', return_value=subprocess.CompletedProcess([], 2, '', '')):
            actual = scan(['checkupdates'], {}, {}, 200, repository=True)
        self.assertEqual(actual['count'], 0)
        self.assertIsNone(actual['error'])

    def test_partial_success_is_labelled(self):
        values = results(['a 1 -> 2'])
        values['aur'] = result(error='offline')
        with patch('subprocess.run') as send:
            notify(values, {})
            self.assertIn('Częściowy wynik', send.call_args.args[0][-1])

    def test_delivery_failure_retries_and_database_is_removed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            seen = []
            def fake_scan(command, environment, previous, now, repository=False):
                database = Path(environment['CHECKUPDATES_DB'])
                database.mkdir(exist_ok=True)
                (database / 'fixture.db').touch()
                seen.append(database)
                return result(['a 1 -> 2'] if repository else [])
            namespace = main.__globals__
            with patch.dict(os.environ, {'XDG_STATE_HOME': str(root / 'state'), 'RUNTIME_DIRECTORY': str(root)}), patch.dict(namespace, {'scan': fake_scan, 'wait_for_packages': lambda: (0, 0), 'package_state': lambda: (0, 0)}), patch('subprocess.run', side_effect=subprocess.CalledProcessError(1, 'notify-send')) as send, contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(main(), 1)
                state = json.loads((root / 'state/update-notifier/status.json').read_text())
                self.assertEqual(state['notified'], [])
                self.assertTrue(all(not path.exists() for path in seen))
                send.side_effect = None
                send.return_value = subprocess.CompletedProcess([], 0)
                self.assertEqual(main(), 0)
                state = json.loads((root / 'state/update-notifier/status.json').read_text())
                self.assertEqual(state['notified'], ['repo:a:2'])
                self.assertTrue(all(not path.exists() for path in seen))
                self.assertEqual(main(), 0)
                self.assertEqual(send.call_count, 2)

if __name__ == '__main__':
    unittest.main(verbosity=2)
