"""Real Quickshell/Wayland/Polkit, with a private authority and helper protocol."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time
import dbus
from _common import ROOT, ipc_json, ipc_reply, qml_errors, runtime_log, stop_process_group, tool


def eventually(read, predicate, label, timeout=10):
    until = time.monotonic() + timeout
    value = None
    while time.monotonic() < until:
        value = read()
        if predicate(value):
            return value
        time.sleep(.025)
    raise AssertionError(f'{label}: {value}')


def run(environment, base, output, first, hypr, launch):
    env = dict(environment)
    entry = ROOT / 'authentication-test.qml'
    env.update(PUTKIN_AUTHENTICATION_TEST=str(base), PUTKIN_AUTH_CONFIG=str(entry),
               DBUS_SYSTEM_BUS_ADDRESS='unix:path=' + str(base/'auth-bus'),
               DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(base/'auth-bus'))
    (base/'authentication-fixture').touch()
    (base/'polkit-policy').write_text('auth sufficient pam_fprintd.so max-tries=1 timeout=2\n')
    with (output/'authentication-fixture-build.log').open('w') as log:
        subprocess.run([tool('cc'), '-std=c11', '-Wall', '-Wextra', '-Werror', '-shared', '-fPIC',
            str(ROOT/'tests/authentication_session_fixture.c'), '-o', str(base/'session-fixture.so')],
            check=True, stdout=log, stderr=subprocess.STDOUT)
    env['LD_PRELOAD'] = str(base/'session-fixture.so')
    (base/'bin').mkdir()
    (base/'bin/qs').symlink_to(tool('quickshell'))
    env['PATH'] = str(base/'bin') + ':' + env['PATH']
    launch([tool('dbus-daemon'), '--session', '--nofork', '--address='+env['DBUS_SESSION_BUS_ADDRESS']], 'auth-bus', env)
    eventually(lambda: (base/'auth-bus').exists(), bool, 'private bus')
    launch([sys.executable, str(ROOT/'tests/authentication_dbus_fixture.py')], 'auth-authority', env)
    bus = dbus.bus.BusConnection(env['DBUS_SESSION_BUS_ADDRESS'])
    eventually(lambda: bus.name_has_owner('org.freedesktop.PolicyKit1'), bool, 'private authority')
    authority = dbus.Interface(bus.get_object('org.freedesktop.PolicyKit1', '/org/freedesktop/PolicyKit1/Authority'), 'org.putkin.AuthenticationFixture')
    app, log = launch([tool('quickshell'), '--no-color', '--path', str(entry)], 'authentication', env)
    helpers = []
    checks = []
    captures = []
    def ipc(target, method, *args, startup=False):
        result = subprocess.run([tool('quickshell'), 'ipc', '--path', str(entry), 'call', target, method, *map(str,args)],
            env=env, capture_output=True, text=True, timeout=5)
        return ipc_reply(result, app, log, starting=startup)
    def state(): return ipc_json(ipc('probe', 'snapshot', startup=True))
    def closed(): return eventually(state, lambda s: s.get('count') == 0 and s.get('channels') == 0, 'requests released')
    def check(text): checks.append(text); print('PASS: ' + text, flush=True)
    def keys(*values):
        command = [tool('wtype')]
        for value in values: command += ['-k', value]
        subprocess.run(command, env=env, capture_output=True, check=True, timeout=5)
    def type_secret(value):
        subprocess.run([tool('wtype'), value, '-k', 'Return'], env=env, capture_output=True, check=True, timeout=5)
    def ask(message, mode='input'):
        child_env = dict(env, SSH_ASKPASS_PROMPT=mode)
        child = subprocess.Popen([sys.executable, str(ROOT/'services/askpass.py'), message], env=child_env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        helpers.append(child)
        return child
    def visible():
        result = eventually(state, lambda s: s.get('active'), 'visible request')
        time.sleep(.35)
        return result
    def capture(name):
        hypr('dismissnotify')
        subprocess.run([str(base/'grim'), '-o', first, str(output/(name+'.png'))], env=env, check=True, capture_output=True, timeout=5)
        captures.append(name+'.png')
    def focus_first():
        hypr('dispatch', 'hl.dsp.focus({monitor = '+json.dumps(first)+'})')
        eventually(lambda: hypr('monitors', data=True), lambda ms: any(m['name'] == first and m['focused'] for m in ms), 'authentication monitor focus')
    try:
        eventually(state, lambda s: s.get('registered'), 'native Polkit registration')
        eventually(state, lambda s: s.get('fingerprintTimeoutMs') == 2000, 'private PAM timeout read')
        helper = ask("Enter passphrase for key '/fixture/key':")
        s = visible(); assert s['title'] == 'Odblokuj klucz SSH' and s['fingerprint'] == 'hidden', s
        capture('authentication-ssh')
        type_secret('hjkl')
        out, err = helper.communicate(timeout=5)
        assert helper.returncode == 0 and out == 'hjkl\n' and not err, (helper.returncode, err)
        closed(); check('real askpass/socket roundtrip, literal hjkl, no secret in IPC and no false fingerprint success')

        helper = ask('Enter PIN for YubiKey:')
        assert visible()['title'] == 'Odblokuj YubiKey'
        capture('authentication-yubikey'); keys('Escape')
        out, err = helper.communicate(timeout=5)
        assert helper.returncode == 1 and out == '' and not err
        closed()
        helper = ask('Confirm user presence for YubiKey', 'none')
        assert visible()['mode'] == 'touch'
        capture('authentication-touch')
        helper.send_signal(signal.SIGTERM); helper.communicate(timeout=5); closed()
        check('YubiKey PIN cancellation and touch notification terminated by its actual caller')

        first_request = ask('Allow use of fixture key?', 'confirm')
        visible()
        queued = ask('Enter PIN for YubiKey:')
        eventually(state, lambda s: s.get('count') == 2, 'queued request')
        keys('l', 'Return')
        assert first_request.communicate(timeout=5)[0] == '\n' and first_request.returncode == 0
        assert visible()['title'] == 'Odblokuj YubiKey'
        ipc('probe', 'block', 'true')
        assert queued.communicate(timeout=5)[0] == '' and queued.returncode == 1
        closed(); ipc('probe', 'block', 'false')
        check('FIFO askpass, vim confirmation, and lock cancels pending secrets')

        authority.Begin('password'); visible()
        assert state()['input']
        capture('authentication-polkit')
        type_secret('wrong')
        eventually(state, lambda s: s.get('error') and s.get('input'), 'native failed PAM conversation retries')
        capture('authentication-password-error')
        type_secret('hjkl'); closed()
        assert json.loads(authority.Snapshot())['outcomes'][-1][1] == 'complete'
        check('native AuthFlow password rejection/retry/success through real libpolkit and fixture helper')

        (base/'fingerprint-event').write_text('0:ready')
        authority.Begin('fingerprint'); visible()
        assert state()['fingerprint'] == 'idle' and not state()['input']
        capture('authentication-fingerprint')
        (base/'fingerprint-event').write_text('1:mismatch')
        eventually(state, lambda s: s.get('fingerprint') == 'error', 'red mismatch')
        assert state()['error'] == ''
        capture('authentication-fingerprint-mismatch')
        (base/'fingerprint-event').write_text('2:reader-error')
        eventually(state, lambda s: s.get('error'), 'reader failure text')
        capture('authentication-reader-error')
        (base/'fingerprint-event').write_text('3:ready')
        eventually(state, lambda s: s.get('error') == '', 'reader recovered')
        (base/'fingerprint-event').write_text('4:success')
        eventually(state, lambda s: s.get('fingerprint') == 'success', 'green only on authorization')
        capture('authentication-fingerprint-success')
        closed()
        check('native fingerprint readiness, red mismatch without text, reader error text, and confirmed green success')

        (base/'fingerprint-event').write_text('0:ready')
        authority.Begin('fallback'); visible()
        (base/'fingerprint-event').write_text('1:mismatch')
        eventually(state, lambda s: s.get('fingerprint') == 'error' and s.get('input'), 'red fingerprint retained alongside password fallback')
        assert not state()['error']
        capture('authentication-fingerprint-password')
        type_secret('hjkl'); closed()
        check('one-attempt fingerprint policy preserves red mismatch feedback when PAM immediately requests a password')

        (base/'fingerprint-event').write_text('0:ready')
        authority.Begin('countdown'); visible()
        eventually(state, lambda s: .3 < s.get('progress', 0) < .8, 'countdown fills while scanning')
        assert state()['countdown'] and not state()['input']
        capture('authentication-countdown')
        eventually(state, lambda s: s.get('input') and s.get('fingerprint') == 'hidden', 'native timeout reveals password')
        assert not state()['countdown'] and state()['progress'] == 1 and not state()['error']
        time.sleep(.05)
        capture('authentication-countdown-password')
        type_secret('hjkl'); closed()
        check('configured countdown fills toward right-hand glyph; native timeout replaces it with focused password and accepts immediate typing')

        # A fresh, private GPG key exercises the actual agent-to-Pinentry caller.
        home = base/'gnupg'; home.mkdir(mode=0o700)
        gpg_env = dict(env, GNUPGHOME=str(home))
        (home/'gpg-agent.conf').write_text('pinentry-program '+str(ROOT/'services/pinentry.py')+'\n')
        fixture = base/'sign-me'; fixture.write_text('Putkin fixture\n')
        subprocess.run([tool('gpg'), '--batch', '--pinentry-mode', 'loopback', '--passphrase-fd', '0',
            '--quick-generate-key', 'Putkin Fixture <fixture@example.invalid>', 'ed25519', 'sign', '1d'],
            env=gpg_env, input='hjkl\n', text=True, capture_output=True, check=True, timeout=30)
        subprocess.run([tool('gpgconf'), '--kill', 'gpg-agent'], env=gpg_env, check=True, capture_output=True, timeout=5)
        child = subprocess.Popen([tool('gpg'), '--batch', '--detach-sign', '--output', str(base/'fixture.sig'), str(fixture)],
            env=gpg_env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
        helpers.append(child)
        visible(); capture('authentication-gpg'); type_secret('hjkl')
        out, err = child.communicate(timeout=15)
        assert child.returncode == 0, err
        closed()
        subprocess.run([tool('gpg'), '--verify', str(base/'fixture.sig'), str(fixture)], env=gpg_env, check=True, capture_output=True, timeout=5)
        subprocess.run([tool('gpgconf'), '--kill', 'all'], env=gpg_env, check=True, capture_output=True, timeout=5)
        check('actual private gpg-agent calls Putkin Pinentry; entered passphrase produces a verifiable fixture signature')

        hypr('eval', 'hl.monitor({output = '+json.dumps(first)+', mode = "1920x1080@60", position = "2000x0", scale = 1.25})')
        focus_first()
        helper = ask('Enter PIN for YubiKey:'); assert visible()['screen'] == first; capture('authentication-scale-125')
        keys('Escape'); helper.communicate(timeout=5); closed()
        hypr('eval', 'hl.monitor({output = '+json.dumps(first)+', mode = "640x480@60", position = "2000x0", scale = 2})')
        focus_first()
        helper = ask("Enter passphrase for key '/fixture/"+'long-path/'*30+"key':")
        assert visible()['screen'] == first
        subprocess.run([tool('wtype'), 'hjkl'], env=env, check=True, capture_output=True, timeout=5)
        keys('Tab', 'Tab'); capture('authentication-small'); keys('Return')
        out, err = helper.communicate(timeout=5)
        assert helper.returncode == 0 and out == 'hjkl\n' and not err
        closed()
        hypr('eval', 'hl.monitor({output = '+json.dumps(first)+', mode = "1920x1080@60", position = "2000x0", scale = 1})')
        check('native 1.25 scale and 320×240 logical screen, long key name scrolls to keyboard controls without losing the secret')

        focus_first()
        helper = ask('Enter PIN for YubiKey:'); assert visible()['screen'] == first
        hypr('output', 'remove', first)
        out, err = helper.communicate(timeout=5)
        assert helper.returncode == 1 and not out and not err
        closed()
        check('removing the active authentication monitor cancels the request and releases its channel')

        for hard in ('false', 'true'):
            helper = ask('Enter PIN for YubiKey:'); visible()
            previous = state()['generation']
            ipc('probe', 'reload', hard)
            out, err = helper.communicate(timeout=5)
            assert helper.returncode == 1 and out == '' and not err
            eventually(state, lambda s: s.get('registered') and s.get('generation') != previous, 'reload registration')
            closed()
        assert not list((base/'r').glob('putkin-auth-*'))
        assert not qml_errors(runtime_log(log)), runtime_log(log)
        assert 'hjkl' not in runtime_log(log)
        check('soft/hard reload closes secret channels, releases private sockets and re-registers the native agent; no QML warnings')
        return {'checks': checks, 'captures': captures, 'result': 'PASS',
                'limits': 'fixture session discovery, private authority and replaced helper; no host PAM or physical fingerprint reader'}
    finally:
        for child in helpers: stop_process_group(child)
        if (base/'gnupg').exists():
            subprocess.run([tool('gpgconf'), '--kill', 'all'], env=dict(env, GNUPGHOME=str(base/'gnupg')), capture_output=True, timeout=5)
        stop_process_group(app)
