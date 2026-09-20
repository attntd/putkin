"""Native protocol/PAM tests inside the existing private Wayland namespace."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'scripts'))
from _common import ipc_json, ipc_reply, qml_errors, runtime_log, tool, stop_process_group


def eventually(read, predicate, description, seconds=8):
    end = time.monotonic() + seconds
    value = None
    while time.monotonic() < end:
        value = read()
        if predicate(value): return value
        time.sleep(.04)
    raise AssertionError(f'{description}: {value}')


def run(environment, base, output, first, hypr, launch):
    import dbus
    env = dict(environment)
    assert Path('/proc/1/comm').read_text().strip() == 'bwrap'
    assert env.get('PUTKIN_WAYLAND_TEST_DIR') == str(base)
    assert not Path('/etc/pam.d/login').exists(), 'host PAM must be masked'
    address = 'unix:path=' + str(base/'bus')
    marker = base/'test-only'; marker.touch()
    env.update(DBUS_SYSTEM_BUS_ADDRESS=address, DBUS_SESSION_BUS_ADDRESS=address,
               PUTKIN_TEST_MARKER=str(marker), XDG_SESSION_ID='test-session', PUTKIN_TEST_PAM=str(base/'pam'))
    with (output/'pam-build.log').open('w') as log:
        subprocess.run([tool('cc'), '-std=c11', '-Wall', '-Wextra', '-Werror', '-fPIC', '-shared',
                        str(ROOT/'tests/session_pam_fixture.c'), '-o', str(base/'pam-fixture.so'), '-lpam'],
                       check=True, stdout=log, stderr=subprocess.STDOUT)
    # Exercise the exact production password stack and its absolute include,
    # but replace system-auth inside masked /etc/pam.d with our only secret
    # verifier. The system pam_shells/pam_nologin checks do not handle secrets.
    shutil.copy2(ROOT/'config/pam.d/putkin-password', base/'pam/putkin-password')
    (base/'pam/system-auth').write_text(f'auth required {base}/pam-fixture.so\n')
    (base/'pam/putkin-fingerprint').write_text(f'auth required {base}/pam-fixture.so fingerprint\n')
    launch([tool('dbus-daemon'), '--session', '--nofork', '--address='+address], 'session-bus', env)
    eventually(lambda: (base/'bus').exists(), bool, 'private session bus')
    launch([sys.executable, '-B', str(ROOT/'tests/session_dbus_fake.py')], 'session-login1', env)
    bus = dbus.bus.BusConnection(address)
    eventually(lambda: bus.name_has_owner('org.putkin.SessionFixture'), bool, 'fixture logind')
    fixture = dbus.Interface(bus.get_object('org.putkin.SessionFixture', '/org/freedesktop/login1'), 'org.putkin.SessionFixture')
    entry = str(ROOT/'native-session-test.qml')
    app, log = launch([tool('quickshell'), '--no-color', '--path', entry], 'native-session', env)
    def ipc(method, *args, startup=False):
        reply = subprocess.run([tool('quickshell'), 'ipc', '--path', entry, 'call', 'probe', method, *map(str,args)],
                               env=env, text=True, capture_output=True, timeout=4)
        return ipc_reply(reply, app, log, starting=startup)
    def state(): return ipc_json(ipc('snapshot', startup=True))
    def type_password(text):
        subprocess.run([tool('wtype'), text, '-k', 'Return'], env=env, check=True, capture_output=True, timeout=4)
    def activity():
        subprocess.run([tool('wtype'), '-k', 'Escape'], env=env, check=True, capture_output=True, timeout=4)
    checks, captures = [], []
    def check(text): checks.append(text); print('PASS: '+text, flush=True)
    def capture(name, monitor=first):
        hypr('dismissnotify')
        path = output/(name+'.png')
        result = subprocess.run([str(base/'grim'), '-o', monitor, str(path)], env=env, capture_output=True, timeout=5)
        assert result.returncode == 0, result.stderr
        captures.append(path.name)
    def locked():
        assert ipc('request') == 'true'
        return eventually(state, lambda s: s.get('secure') and s.get('surfaces') == len(s.get('screens',[])), 'all screens locked')
    try:
        initial = eventually(state, lambda s: s.get('ready'), 'native shell')
        assert not initial['locked'] and initial['surfaces'] == 0 and not initial['error'], initial
        locked(); capture('native-lock')
        assert not state()['watching'] and ipc('reload') == 'deferred'
        type_password('wrong')
        eventually(state, lambda s: s.get('passwordFailed') and not s.get('passwordBusy'), 'PAM rejection')
        assert state()['secure']; capture('native-lock-rejected')
        activity(); type_password('hjkl')
        eventually(state, lambda s: not s.get('locked') and s.get('surfaces') == 0, 'password authentication')
        check('native lock covers all outputs; bad password stays locked; hjkl typed literally unlocks via actual fixture PAM')

        (base/'fingerprint-result').write_text('waiting')
        ipc('fingerprintEnabled', 'true'); locked()
        (base/'fingerprint-result').write_text('error')
        eventually(state, lambda s: s.get('fingerprint') == 'error', 'fingerprint rejection')
        capture('native-fingerprint-error')
        eventually(state, lambda s: s.get('fingerprint') == 'idle', 'fingerprint reset')
        assert state()['secure']
        (base/'fingerprint-result').write_text('success')
        eventually(state, lambda s: not s.get('locked') and s.get('fingerprint') == 'success', 'fingerprint authentication')
        check('separate PAM fingerprint conversation reports error/reset and unlocks only on success')
        (base/'fingerprint-result').write_text('waiting')
        locked(); type_password('hjkl')
        eventually(state, lambda s: not s.get('locked'), 'password while fingerprint waits')
        check('password remains usable while the independent fingerprint conversation waits')
        ipc('fingerprintEnabled', 'false')

        locked()
        hypr('output', 'create', 'headless')
        added = eventually(lambda: hypr('monitors',data=True), lambda ms: len(ms) == 3, 'hotplug')
        new = next(m['name'] for m in added if m['name'].startswith('HEADLESS-') and m['name'] != first)
        eventually(state, lambda s: s.get('surfaces') == 3 and s.get('secure'), 'new output lock')
        capture('native-lock-hotplug', new)
        hypr('output', 'remove', new)
        eventually(state, lambda s: s.get('surfaces') == 2 and s.get('secure'), 'removed output lock')
        type_password('hjkl'); eventually(state, lambda s: not s.get('locked'), 'hotplug unlock')
        assert ipc('reload') == 'accepted'
        eventually(state, lambda s: s.get('ready') and not s.get('locked') and s.get('watching'), 'unlocked reload')
        check('locked hotplug covers new output; reload deferred until unlocked')

        # Real IdleMonitor events with shortened thresholds, no host hardware.
        activity(); ipc('enableIdle', 'true')
        eventually(state, lambda s: s.get('dimmed') and abs(s.get('percent',0)-10)<1, 'native dim timer', 5)
        eventually(state, lambda s: s.get('displaysOff'), 'native DPMS timer', 3)
        eventually(lambda: hypr('monitors', data=True), lambda ms: ms and all(not m['dpmsStatus'] for m in ms), 'compositor DPMS off')
        eventually(state, lambda s: s.get('secure'), 'native automatic lock', 3)
        activity()
        eventually(state, lambda s: not s.get('displaysOff') and not s.get('dimmed'), 'activity restores display and brightness')
        eventually(lambda: hypr('monitors', data=True), lambda ms: ms and all(m['dpmsStatus'] for m in ms), 'compositor DPMS restored')
        assert state()['secure']; type_password('hjkl')
        eventually(state, lambda s: not s.get('locked'), 'unlock after idle')
        ipc('enableIdle','false')
        check('native idle thresholds dim, DPMS off, lock; activity restores DPMS/brightness without unlocking')

        fixture.Inhibitors('idle:sleep'); activity(); ipc('enableIdle','true')
        time.sleep(4.5)
        s = state(); assert not s['locked'] and not s['dimmed'] and not s['displaysOff'], s
        fixture.Inhibitors('sleep'); activity()
        eventually(state, lambda s: s.get('secure'), 'background mode permits lock', 7)
        time.sleep(4.5)
        assert not any(e[0] in ('suspend', 'suspendThenHibernate') for e in json.loads(fixture.Snapshot()))
        ipc('enableIdle','false'); activity(); type_password('hjkl')
        eventually(state, lambda s: not s.get('locked'), 'background unlock')
        check('presentation suppresses native idle events; background permits locking but prevents automatic sleep')

        fixture.Inhibitors(''); fixture.Clear(); activity(); ipc('enableIdle','true')
        eventually(lambda: json.loads(fixture.Snapshot()), lambda es: any(e[0]=='suspendThenHibernate' for e in es), 'automatic suspend-then-hibernate through secure lock', 12)
        assert state()['secure']
        ipc('enableIdle','false'); activity(); type_password('hjkl')
        eventually(state, lambda s: not s.get('locked'), 'final unlock')
        check('native automatic SuspendThenHibernate reaches fake logind only after compositor secure')
        assert not qml_errors(runtime_log(log)), runtime_log(log)
        # Last: killing the actual client while locked must keep the compositor locked.
        locked(); stop_process_group(app)
        assert hypr('locked') == 'true'
        check('client termination leaves compositor session locked')
        return {'checks': checks, 'captures': captures, 'result':'PASS',
                'isolation':'private compositor, buses, fixture PAM only; real password/fingerprint hardware untouched'}
    finally:
        bus.close()
