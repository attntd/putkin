"""Screenshot acceptance against real private Wayland surfaces and clipboard."""
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import time
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from _common import ipc_json, ipc_reply, qml_errors, runtime_log, tool


def eventually(read, predicate, label, seconds=8):
    end = time.monotonic() + seconds
    value = None
    while time.monotonic() < end:
        value = read()
        if predicate(value):
            return value
        time.sleep(.04)
    raise AssertionError(f"{label}: {value}")


def run(environment, base, output, first, hypr, launch):
    assert Path('/proc/1/comm').read_text().strip() == 'bwrap'
    assert environment.get('PUTKIN_WAYLAND_TEST_DIR') == str(base)
    env = dict(environment, PUTKIN_KEYBOARD_TEST='1', HOME=str(base / 'home'))
    Path(env['HOME']).mkdir()
    entry = str(ROOT / 'keyboard-test.qml')
    app, log = launch([tool('quickshell'), '--no-color', '--path', entry], 'screenshot', env)
    checks, captures, timings = [], [], []
    def ipc(target, method, *args, startup=False):
        reply = subprocess.run([tool('quickshell'), 'ipc', '--path', entry, 'call', target, method, *map(str, args)],
                               env=env, text=True, capture_output=True, timeout=5)
        return ipc_reply(reply, app, log, starting=startup)
    def state(): return ipc_json(ipc('probe', 'snapshot', startup=True))
    def shot(): return state().get('screenshot', {})
    def phase(value):
        return eventually(shot, lambda s: s.get('phase') == value
                          and (value != 'selecting' or s.get('selectionReady'))
                          and (value != 'preview' or s.get('previewReady')), value)
    def keys(*values):
        command = [tool('wtype')]
        for value in values: command += ['-k', value]
        subprocess.run(command, env=env, check=True, capture_output=True, timeout=5)
    def check(text): checks.append(text); print('PASS: ' + text, flush=True)
    def temporary(): return list(Path(env['XDG_RUNTIME_DIR']).glob('putkin-screenshot-*'))
    def clipboard():
        return subprocess.run([tool('wl-paste'), '--type', 'image/png'], env=env, check=True, capture_output=True, timeout=5).stdout
    def idle():
        eventually(shot, lambda s: s.get('phase') == 'idle' and not s.get('busy'), 'screenshot cleanup')
        assert not temporary(), temporary()
    def target():
        return next((c for c in hypr('clients', data=True) if c['title'] == 'Putkin keyboard target'), None)
    def focus():
        hypr('dispatch', 'hl.dsp.focus({monitor=' + json.dumps(first) + '})')
        window = target()
        if window:
            hypr('dispatch', 'hl.dsp.focus({window=' + json.dumps('address:' + window['address']) + '})')
    def capture(name):
        path = output / (name + '.png')
        subprocess.run([str(base / 'grim'), '-o', first, str(path)], env=env, check=True, capture_output=True, timeout=5)
        captures.append(path.name)
        return path
    def image():
        result = phase('preview')
        eventually(lambda: hypr('activewindow', data=True), lambda c: c.get('title') == 'Zrzut ekranu', 'preview keyboard focus')
        path = Path(unquote(urlparse(result['source']).path))
        assert path.is_relative_to(base) and path.exists(), result
        data = path.read_bytes()
        assert clipboard() == data
        return result, path, data

    eventually(state, lambda s: s.get('ready') and not s.get('keyboardBusy'), 'keyboard ready')
    assert not state()['problem'], state()
    window = eventually(target, bool, 'target window')
    assert any(b.get('description') == 'Putkin:screenshot' and b['key'] == 'Print' for b in hypr('binds', data=True))
    hypr('dismissnotify'); focus()
    time.sleep(.2)
    baseline = capture('screenshot-baseline')

    for key in ('q', 'Escape'):
        keys('Print'); phase('selecting')
        assert not temporary() and not shot()['busy']
        keys(key); idle()
    check('real Print opens selection; Q and Escape cancel without PNG or capture worker')

    keys('Print'); phase('selecting'); capture('screenshot-selection')
    started = time.monotonic(); keys('Return'); result, path, data = image()
    timings.append({'mode': 'screen', 'confirm_to_observed_preview_ms': round((time.monotonic() - started) * 1000)})
    assert (result['width'], result['height']) == (1920, 1080), result
    preview = eventually(lambda: hypr('clients', data=True), lambda cs: any(c['title'] == 'Zrzut ekranu' for c in cs), 'floating preview')
    preview = next(c for c in preview if c['title'] == 'Zrzut ekranu')
    assert preview['floating'], preview
    # Pixel equality on desktop background catches the dimmer in the PNG.
    def pixel(source):
        return subprocess.run([tool('magick'), str(source), '-crop', '20x20+100+100', '+repage', '-depth', '8', 'RGB:-'],
                              env=env, check=True, capture_output=True, timeout=5).stdout
    assert pixel(path) == pixel(baseline), 'selection shade was captured'
    shutil.copy2(path, output / 'screenshot-full.png'); captures.append('screenshot-full.png')
    capture('screenshot-preview')
    keys('q'); idle(); assert clipboard() == data and not path.exists()
    check('Enter captures full current output after unmap; native preview floats; PNG copied before preview and survives Q')

    # Drag with actual Wayland pointer events; release alone must not capture.
    focus(); keys('Print'); phase('selecting')
    hypr('dispatch', 'hl.dsp.cursor.move({x=2300,y=250})')
    subprocess.run([str(base / 'click'), '-200', '-150'], env=env, check=True, capture_output=True, timeout=5)
    region = shot(); assert region['phase'] == 'selecting' and not temporary(), region
    assert region['selection']['width'] == 200 and region['selection']['height'] == 150, region
    capture('screenshot-region-selection')
    keys('Return'); result, path, data = image()
    assert (result['width'], result['height']) == (200, 150), result
    keys('f'); idle(); saved = Path(shot()['saved'])
    assert saved.is_relative_to(base / 'home') and saved.read_bytes() == data
    assert saved.stat().st_mode & 0o777 == 0o600 and not path.exists()
    check('real reverse drag waits for Enter; cropped PNG has exact dimensions; F saves identical bytes with mode 0600')

    # Production launcher and action controller retain the pre-launcher window.
    focus(); original = target()
    assert ipc('launcher', 'openCommands') == 'ok'
    eventually(state, lambda s: s.get('searchFocus'), 'command field')
    subprocess.run([tool('wtype'), 'screenshot'], env=env, check=True, capture_output=True, timeout=5)
    eventually(state, lambda s: any(r.get('action') == 'screenshot' for r in s.get('results', [])), 'screenshot command')
    keys('Return'); selected = phase('selecting')
    assert selected['window'].removeprefix('0x') == original['address'].removeprefix('0x'), selected
    keys('w'); result, path, data = image()
    assert (result['width'], result['height']) == tuple(original['size']), (result, original)
    keys('Return'); idle(); assert Path(shot()['saved']).read_bytes() == data
    check(':screenshot uses real launcher input; W captures the original active window; Enter saves preview')

    # With long compositor fades enabled, the namespace rule must still unmap
    # instantly. Verify the resulting PNG against unchanged underlying pixels.
    hypr('eval', 'hl.config({animations={enabled=true}})')
    focus(); keys('Print'); phase('selecting'); keys('Return')
    result, path, data = image()
    shutil.copy2(path, output / 'screenshot-animations.png'); captures.append('screenshot-animations.png')
    assert pixel(path) == pixel(baseline), (pixel(path)[:3], pixel(baseline)[:3])
    keys('Escape'); idle(); assert clipboard() == data
    check('compositor animations do not retain dimmer in capture; Escape closes preview and preserves clipboard')

    # Reapply the named rule after both types of shell reload and after the
    # compositor clears its rules. Exercise the resulting native capture too.
    for cycle in range(2):
        for mode in ('soft', 'hard', 'compositor'):
            # Keep the reference window static while the shell recreates it;
            # re-enable compositor fades before opening the screenshot overlay.
            hypr('eval', 'hl.config({animations={enabled=false}})')
            previous = state()['generation']
            if mode == 'compositor':
                assert hypr('reload') == 'ok'
            else:
                ipc('probe', 'softReload' if mode == 'soft' else 'reload')
            eventually(state, lambda s: s.get('ready') and not s.get('keyboardBusy')
                       and (mode == 'compositor' or s.get('generation') != previous), 'reload ready')
            eventually(lambda: hypr('binds', data=True),
                       lambda bs: sum(b.get('description') == 'Putkin:screenshot' and b['key'] == 'Print'
                                      for b in bs) == 1, 'one Print binding after reload')
            eventually(target, bool, 'target restored after reload')
            assert not state()['problem'], state()
            hypr('eval', 'hl.config({animations={enabled=true}})')
            focus(); time.sleep(.2)
            reference = capture(f'screenshot-reload-{mode}-{cycle + 1}-baseline')
            keys('Print'); phase('selecting'); keys('Return')
            result, path, data = image()
            assert (result['width'], result['height']) == (1920, 1080), result
            assert pixel(path) == pixel(reference), f'selection shade captured after {mode} reload'
            name = f'screenshot-reload-{mode}-{cycle + 1}.png'
            shutil.copy2(path, output / name); captures.append(name)
            keys('Escape'); idle(); assert clipboard() == data
            assert not hypr('configerrors').strip()
            assert not qml_errors(runtime_log(log)), runtime_log(log)
            check(f'{mode} reload {cycle + 1}: Print captures clean PNG, clipboard survives and runtime has no warnings')

    # Fractional scaling and a negative output origin use layout coordinates.
    hypr('eval', 'hl.monitor({output=' + json.dumps(first) + ',mode="1920x1080@60",position="-1536x0",scale=1.25})')
    eventually(lambda: hypr('monitors', data=True), lambda ms: any(m['name'] == first and m['scale'] == 1.25 for m in ms), 'fractional monitor')
    time.sleep(.2); focus(); keys('Print'); phase('selecting'); keys('Return')
    result, path, data = image(); assert (result['width'], result['height']) == (1920, 1080), result
    keys('Escape'); idle()
    check('fractional scale and negative monitor origin preserve native output pixel dimensions')

    keys('Print'); phase('selecting'); assert not temporary()
    hypr('output', 'remove', first); idle()
    assert clipboard() == data
    check('removing the selected monitor cancels the overlay without capturing another output or replacing clipboard')

    assert not qml_errors(runtime_log(log)), runtime_log(log)
    return {'result': 'PASS', 'checks': checks, 'captures': captures, 'timings': timings,
            'final': shot(), 'isolation': 'private Wayland, clipboard, XDG and buses; hardware/session mocks'}
