#!/usr/bin/python3
"""Private libpolkit helper protocol fixture; never imports or invokes PAM."""
import os
from pathlib import Path
import sys
import time

assert Path('/proc/1/comm').read_text().strip() == 'bwrap'
base = Path(os.environ['PUTKIN_AUTHENTICATION_TEST'])
assert str(base).startswith('/tmp/') and (base / 'authentication-fixture').exists()
cookie = sys.stdin.readline().strip()
if cookie.startswith('password-'):
    print('PAM_PROMPT_ECHO_OFF Password:', flush=True)
    response = sys.stdin.readline().rstrip('\n')
    print('SUCCESS' if response == 'hjkl' else 'FAILURE', flush=True)
else:
    print('PAM_TEXT_INFO Place your finger on the fingerprint reader', flush=True)
    deadline = time.monotonic() + 2
    last = ''
    while True:
        if cookie.startswith('countdown-') and time.monotonic() >= deadline:
            print('PAM_ERROR_MSG Verification timed out', flush=True)
            time.sleep(.15)  # Separate event batches must not collapse the row.
            print('PAM_PROMPT_ECHO_OFF Password:', flush=True)
            response = sys.stdin.readline().rstrip('\n')
            print('SUCCESS' if response == 'hjkl' else 'FAILURE', flush=True)
            break
        path = base / 'fingerprint-event'
        event = path.read_text() if path.exists() else ''
        if event != last:
            last = event
            value = event.split(':', 1)[-1]
            if value == 'mismatch':
                print('PAM_ERROR_MSG Failed to match fingerprint', flush=True)
                if cookie.startswith('fallback-'):
                    print('PAM_PROMPT_ECHO_OFF Password:', flush=True)
                    response = sys.stdin.readline().rstrip('\n')
                    print('SUCCESS' if response == 'hjkl' else 'FAILURE', flush=True)
                    break
            elif value == 'reader-error': print('PAM_ERROR_MSG Device already in use by another user', flush=True)
            elif value == 'ready': print('PAM_TEXT_INFO Place your finger on the fingerprint reader', flush=True)
            elif value == 'success':
                print('SUCCESS', flush=True)
                break
        time.sleep(.015)
# Native libpolkit owns termination/reaping; do not generate a premature HUP.
time.sleep(30)
