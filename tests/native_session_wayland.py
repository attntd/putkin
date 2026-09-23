"""Native protocol/PAM tests inside the existing private Wayland namespace."""
import json
import os
from pathlib import Path
import shutil
import signal
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
    # Run the real pam_fprintd and shipped options, against a private D-Bus
    # reader. No libfprint device or host PAM stack is reachable here.
    shutil.copy2(ROOT/'config/pam.d/putkin-fingerprint', base/'pam/putkin-fingerprint')
    launch([tool('dbus-daemon'), '--session', '--nofork', '--address='+address], 'session-bus', env)
    eventually(lambda: (base/'bus').exists(), bool, 'private session bus')
    launch([sys.executable, '-B', str(ROOT/'tests/session_dbus_fake.py')], 'session-login1', env)
    launch([sys.executable, '-B', str(ROOT/'tests/fprint_dbus_fake.py')], 'session-fprintd', env)
    bus = dbus.bus.BusConnection(address)
    eventually(lambda: bus.name_has_owner('org.putkin.SessionFixture'), bool, 'fixture logind')
    fixture = dbus.Interface(bus.get_object('org.putkin.SessionFixture', '/org/freedesktop/login1'), 'org.putkin.SessionFixture')
    eventually(lambda: bus.name_has_owner('org.putkin.FingerprintFixture'), bool, 'fixture fprintd')
    finger = dbus.Interface(bus.get_object('org.putkin.FingerprintFixture', '/net/reactivated/Fprint/Manager'), 'org.putkin.FingerprintFixture')
    def scan_count(): return json.loads(finger.Snapshot()).count('VerifyStart')
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
        return eventually(state, lambda s: s.get('secure') and s.get('surfaces') == len(s.get('screens',[]))
                          and all(alpha == 1 for alpha in s.get('opacities', [])), 'all screens locked and visible')
    def verify_fade_video(path):
        # Lossless recording of the compositor, including frames before the
        # first lock surface. Four corners distinguish a desktop crossfade
        # from a flat grey/black intermediary even when Qt opacity is correct.
        decoded = subprocess.run([tool('ffmpeg'), '-v', 'error', '-i', str(path), '-vf',
                                  'scale=32:18:flags=neighbor', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                                 capture_output=True, check=True, timeout=20).stdout
        size = 32 * 18 * 3
        points = [(2, 2), (29, 2), (2, 15), (29, 15)]
        pixels = [[tuple(frame[(y*32+x)*3:(y*32+x)*3+3]) for x,y in points]
                  for start in range(0, len(decoded), size) if len(frame := decoded[start:start+size]) == size]
        assert len(pixels) > 20, len(pixels)
        desktop = pixels[0]
        assert len(set(desktop)) == 4, desktop
        opaque = min(pixels, key=lambda row: sum(max(c)-min(c) for c in zip(*row)))
        source = [v for pixel in desktop for v in pixel]
        target = [v for pixel in opaque for v in pixel]
        vector = [b-a for a,b in zip(source,target)]
        norm = sum(v*v for v in vector)
        samples = []
        for row in pixels:
            values = [v for pixel in row for v in pixel]
            alpha = sum((v-a)*delta for v,a,delta in zip(values,source,vector)) / norm
            error = max(abs(v-(a+alpha*delta)) for v,a,delta in zip(values,source,vector))
            samples.append({'alpha': alpha, 'error': error, 'pixels': row})
        (output/'desktop-fade-pixels.json').write_text(json.dumps(samples, indent=2)+'\n')
        assert all(-.02 <= s['alpha'] <= 1.02 and s['error'] < 4 for s in samples), max(samples, key=lambda s:s['error'])
        peak = next(i for i,s in enumerate(samples) if s['alpha'] > .99)
        assert any(.1 < s['alpha'] < .9 for s in samples[:peak]), 'no desktop fade-in'
        assert any(.1 < s['alpha'] < .9 for s in samples[peak:]), 'no desktop fade-out'
        assert samples[-1]['alpha'] < .02, samples[-1]
    try:
        initial = eventually(state, lambda s: s.get('ready'), 'native shell')
        assert not initial['locked'] and initial['surfaces'] == 0 and not initial['error'], initial
        recorder, _ = launch([tool('wf-recorder'), '-D', '-r', '60', '--no-dmabuf', '-o', first,
                              '-c', 'ffv1', '-x', 'bgr0', '-f', str(output/'desktop-fade.mkv')], 'lock-recorder', env)
        time.sleep(.4)
        assert recorder.poll() is None, 'recorder failed to start'
        opening = locked(); capture('native-lock')
        (output/'lock-opening.json').write_text(json.dumps(opening, indent=2)+'\n')
        assert opening['captures'] == len(opening['screens']) and all(opening['animated']), opening
        assert not state()['watching'] and ipc('reload') == 'deferred'
        type_password('wrong')
        eventually(state, lambda s: s.get('passwordFailed') and not s.get('passwordBusy'), 'PAM rejection')
        assert state()['secure']; capture('native-lock-rejected')
        activity(); type_password('hjkl')
        unlocked = eventually(state, lambda s: not s.get('locked') and s.get('surfaces') == 0, 'password authentication')
        time.sleep(.3)
        recorder.send_signal(signal.SIGINT); recorder.wait(timeout=5)
        verify_fade_video(output/'desktop-fade.mkv')
        assert unlocked['captures'] == 0, unlocked
        check('recorded compositor frames crossfade directly from/to desktop without grey intermediary; buffers released on unlock')
        frames = unlocked['fadeFrames']
        (output/'lock-fade-frames.json').write_text(json.dumps(frames, indent=2)+'\n')
        assert any(not f['closing'] and any(0 < a < 1 for a in f['opacities']) for f in frames), frames
        closing = [f for f in frames if f['closing']]
        assert closing and all(f['secure'] for f in closing), closing
        check('native lock covers all outputs; bad password stays locked; hjkl typed literally unlocks via actual fixture PAM')
        check('all native surfaces fade in/out; compositor secure remains true throughout authenticated fade-out')

        ipc('captureEnabled', 'false')
        fallback = locked()
        assert fallback['captures'] == 0 and not any(fallback['animated']), fallback
        assert all(all(a == 1 for a in f['opacities']) for f in fallback['fadeFrames']), fallback
        type_password('hjkl'); eventually(state, lambda s: not s.get('locked'), 'unlock without a desktop capture')
        ipc('captureEnabled', 'true')
        check('missing desktop captures lock immediately and opaquely on every output; password still unlocks')

        scans = scan_count()
        ipc('fingerprintEnabled', 'true'); locked()
        eventually(scan_count, lambda n: n > scans, 'real pam_fprintd scan')
        scans = scan_count()
        finger.Emit('verify-no-match', True)
        eventually(state, lambda s: s.get('fingerprint') == 'error', 'fingerprint rejection')
        capture('native-fingerprint-error')
        eventually(state, lambda s: s.get('fingerprint') == 'idle', 'fingerprint reset')
        eventually(scan_count, lambda n: n > scans, 'retry after mismatch')
        assert state()['secure']
        # Reproduce returning to a lock after the former 30 s PAM deadline.
        started = time.monotonic()
        while time.monotonic() - started < 32:
            time.sleep(.5)
            current = state()
            assert current['secure'] and current['fingerprintActive'], current
        finger.Emit('verify-match', True)
        eventually(state, lambda s: not s.get('locked') and s.get('fingerprint') == 'success', 'fingerprint authentication')
        check('real pam_fprintd reports mismatch/reset and accepts fingerprint after more than 30 seconds waiting')
        locked(); eventually(state, lambda s: s.get('fingerprintActive'), 'parallel fingerprint')
        type_password('hjkl')
        eventually(state, lambda s: not s.get('locked'), 'password while fingerprint waits')
        assert not state()['fingerprintActive']
        check('password remains usable while the independent fingerprint conversation waits')

        scans = scan_count(); locked()
        eventually(scan_count, lambda n: n > scans, 'limited fingerprint conversation')
        for attempt in range(3):
            scans = scan_count()
            finger.Emit('verify-no-match', True)
            if attempt < 2: eventually(scan_count, lambda n: n > scans, 'next limited scan')
        eventually(state, lambda s: not s.get('fingerprintActive'), 'three failed scans stop PAM')
        time.sleep(2.2)
        assert state()['secure'] and not state()['fingerprintActive']
        type_password('hjkl'); eventually(state, lambda s: not s.get('locked'), 'password after scan limit')
        check('three failed fingerprints still stop scanning and retain password authentication')
        ipc('fingerprintEnabled', 'false')

        locked()
        hypr('output', 'create', 'headless')
        added = eventually(lambda: hypr('monitors',data=True), lambda ms: len(ms) == 3, 'hotplug')
        new = next(m['name'] for m in added if m['name'].startswith('HEADLESS-') and m['name'] != first)
        added_lock = eventually(state, lambda s: s.get('surfaces') == 3 and s.get('secure'), 'new output lock')
        assert added_lock['animated'].count(False) == 1, added_lock
        assert all(a == 1 for a in added_lock['opacities']), added_lock
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

        fixture.Inhibitors(''); fixture.Clear(); fixture.Capability('idleSuspend', 'na'); ipc('refresh')
        eventually(state, lambda s: not s.get('sleepAvailable'), 'unsupported automatic sleep')
        activity(); ipc('enableIdle','true')
        time.sleep(8.5)
        assert state()['secure'] and not state()['error'], state()
        assert not any(e[0] in ('suspend', 'suspendThenHibernate') for e in json.loads(fixture.Snapshot()))
        ipc('enableIdle','false'); activity(); type_password('hjkl')
        eventually(state, lambda s: not s.get('locked'), 'unlock with unsupported automatic sleep')
        assert not state()['error'], state()
        check('unsupported automatic sleep keeps lock/password working without a session error after unlock')

        fixture.Capability('idleSuspend', 'yes'); ipc('refresh')
        eventually(state, lambda s: s.get('sleepAvailable'), 'automatic sleep supported again')
        fixture.Clear(); activity(); ipc('enableIdle','true')
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
