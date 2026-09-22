"""Launcher preview in real layer surfaces, with private input and clipboard fixtures."""
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from _common import ipc_json, ipc_reply, qml_errors, runtime_log, tool
from screenshot_wayland import eventually


def run(environment, base, output, first, hypr, launch):
    assert Path('/proc/1/comm').read_text().strip() == 'bwrap'
    assert environment.get('PUTKIN_WAYLAND_TEST_DIR') == str(base)
    env = dict(environment, PUTKIN_KEYBOARD_TEST='1', HOME=str(base / 'home'))
    Path(env['HOME']).mkdir()
    entry = str(ROOT / 'keyboard-test.qml')
    app, log = launch([tool('quickshell'), '--no-color', '--path', entry], 'launcher-preview', env)
    checks, captures, transitions, commands = [], [], {}, {}

    def ipc(target, method, *args, startup=False):
        reply = subprocess.run([tool('quickshell'), 'ipc', '--path', entry, 'call', target, method, *map(str, args)],
                               env=env, text=True, capture_output=True, timeout=5)
        return ipc_reply(reply, app, log, starting=startup)

    def state(): return ipc_json(ipc('probe', 'launcherSnapshot', startup=True))
    def keys(*values):
        command = [tool('wtype')]
        for value in values: command += ['-k', value]
        subprocess.run(command, env=env, check=True, capture_output=True, timeout=5)

    def click(x, y):
        monitor = next(m for m in hypr('monitors', data=True) if m['name'] == first)
        hypr('dispatch', 'hl.dsp.cursor.move({x=' + str(round(monitor['x'] + x)) + ',y=' + str(round(monitor['y'] + y)) + '})')
        subprocess.run([str(base / 'click')], env=env, check=True, capture_output=True, timeout=5)

    def capture(name):
        path = output / (name + '.png')
        subprocess.run([str(base / 'grim'), '-o', first, str(path)], env=env, check=True, capture_output=True, timeout=5)
        captures.append(path.name)

    def check(description):
        checks.append(description)
        print('PASS: ' + description, flush=True)

    def centered(result, height):
        field = result['search']
        assert abs(field['y'] + field['height'] / 2 - height / 2) <= .5, result

    def transition(name, ready):
        samples = []
        def sample():
            result = state()
            samples.append({key: result[key] for key in ('search', 'list', 'primaryHeight', 'resultsOpacity',
                'resultCount', 'previewOpacity', 'displayedPreviewId')})
            return result
        result = eventually(sample, ready, name)
        transitions[name] = samples
        return result

    def open_launcher():
        hypr('dispatch', 'hl.dsp.focus({monitor=' + json.dumps(first) + '})')
        assert ipc('launcher', 'openClipboard') == 'ok'
        return eventually(state, lambda s: s.get('focus') == 'launcherSearch' and s.get('frame')
                          and s.get('text') and s.get('opacity') == 1
                          and s.get('resultsOpacity') == 1 and s.get('previewOpacity') == 1
                          and s.get('previewCurrent'), 'clipboard preview ready')

    eventually(lambda: ipc_json(ipc('probe', 'snapshot', startup=True)),
               lambda s: s.get('ready') and not s.get('keyboardBusy'), 'private shell ready')
    eventually(lambda: hypr('clients', data=True),
               lambda clients: any(client.get('title') == 'Putkin keyboard target' for client in clients),
               'fixture target mapped before opening the launcher')
    ipc('probe', 'launcherFixture')
    hypr('dismissnotify')
    hypr('dispatch', 'hl.dsp.focus({monitor=' + json.dumps(first) + '})')
    subprocess.run([tool('wtype'), '-M', 'logo', '-s', '100', '-k', 'space', '-m', 'logo'],
                   env=env, check=True, capture_output=True, timeout=5)
    eventually(state, lambda s: s['focus'] == 'launcherSearch' and s['opacity'] == 1, 'Super+Space search focus')
    subprocess.run([tool('wtype'), ':'], env=env, check=True, capture_output=True, timeout=5)
    eventually(state, lambda s: s['fieldText'] == ':' and s['chipText'] == '', 'colon before commit')
    keys('space')
    result = eventually(state, lambda s: s['mode'] == 'command' and s['chipText'] == 'Komenda'
                        and s['fieldText'] == '' and s['focus'] == 'launcherSearch'
                        and s['resultsCurrent'] and s['resultsOpacity'] == 1
                        and len(s['rows']) == 5 and all(r['iconReady'] for r in s['rows']), 'colon-space command chip')
    centered(result, 1080)
    assert result['list']['height'] == 5 * 52 and result['resultCount'] > 5, result
    assert result['rows'][0] == {'action': 'balanced', 'category': 'Bateria', 'categoryVisible': True,
                                 'icon': 'battery_android_full', 'iconReady': True}, result
    commands['all'] = result
    capture('launcher-native-command-categories')
    subprocess.run([tool('wtype'), 'bal'], env=env, check=True, capture_output=True, timeout=5)
    result = transition('commands-to-balanced', lambda s: s['fieldText'] == 'bal' and s['resultCount'] == 1
                        and s['resultsCurrent'] and s['resultsOpacity'] == 1)
    assert result['rows'][0]['action'] == 'balanced' and result['rows'][0]['category'] == 'Bateria', result
    assert result['focus'] == 'launcherSearch' and result['activations'] == 0, result
    assert any(0 < s['resultsOpacity'] < 1 for s in transitions['commands-to-balanced']), transitions
    assert all(s['search']['y'] == result['search']['y'] for s in transitions['commands-to-balanced']), transitions
    commands['balanced'] = result
    capture('launcher-native-balanced')
    keys('Escape', 'Escape')
    eventually(state, lambda s: not s['loaded'], 'close command results without activation')
    check('Super+Space, colon then space commits Komenda with focus; categorized vectors, five rows and balanced fade')

    result = open_launcher()
    centered(result, 1080)
    frame, surface = result['frame'], result['surface']
    assert frame['width'] == frame['height'] == 320 and frame['y'] == surface['y'], result
    assert frame['x'] == surface['x'] + 648, result
    assert result['previewScrollbar']['height'] == frame['height'] - 24 and result['previewScrollSize'] < 1, result
    capture('launcher-native-text')
    keys('Escape', 'l')
    eventually(state, lambda s: s['focus'] == 'launcherPreview', 'right to preview')
    keys('j')
    eventually(state, lambda s: s['contentY'] > 0, 'scroll preview')
    keys('h', 'j')
    result = transition('text-to-image', lambda s: s['previewId'] == '11' and s['imageReady']
                        and s['previewCurrent'] and s['previewOpacity'] == 1)
    assert any(0 < s['previewOpacity'] < 1 for s in transitions['text-to-image']), transitions
    assert all(s['search']['y'] == result['search']['y'] for s in transitions['text-to-image']), transitions
    assert result['activations'] == 0
    capture('launcher-native-image')
    check('native text/image rendering, square aligned at top, hjkl navigation and scrolling without copying')

    frame = result['frame']
    click(frame['x'] + frame['width'] / 2, frame['y'] + frame['height'] / 2)
    assert state()['active'] == 'launcher'
    keys('h')
    eventually(state, lambda s: s['focus'] == 'launcherResults', 'return from clicked preview')
    # The area below the short list is outside both input rectangles.
    click(surface['x'] + 20, surface['y'] + result['primaryHeight'] + 24)
    eventually(state, lambda s: s['active'] == '' and not s['loaded'], 'outside below list')
    assert state()['text'] == '' and state()['previewId'] == ''
    check('preview click stays inside the grab; transparent area below the list dismisses; close releases preview')

    result = open_launcher()
    click(result['surface']['x'] + 644, result['frame']['y'] + 30)
    eventually(state, lambda s: not s['loaded'], 'gap outside mask')
    check('gap between the two frames remains outside the native input mask')

    assert ipc('launcher', 'toggle') == 'ok'
    eventually(state, lambda s: s.get('focus') == 'launcherSearch', 'application search focus')
    ipc('probe', 'query', ':a ')
    result = eventually(state, lambda s: s['opacity'] == 1 and s['resultCount'] == 20 and s['resultsCurrent']
                        and s['resultsOpacity'] == 1, 'five visible application results')
    centered(result, 1080)
    assert result['list']['height'] == 5 * 52, result
    capture('launcher-native-five-results')
    keys('Escape', 'End')
    result = eventually(state, lambda s: s['selectedIndex'] == 19 and s['listContentY'] > 0, 'last application result')
    assert result['activations'] == 0, result
    ipc('probe', 'query', 'Aplikacja 19')
    result = transition('list-to-one-result', lambda s: s['resultCount'] == 1 and s['resultsCurrent']
                        and s['resultsOpacity'] == 1)
    centered(result, 1080)
    assert result['list']['height'] == 52, result
    assert any(0 < s['resultsOpacity'] < 1 for s in transitions['list-to-one-result']), transitions
    assert all(s['search']['y'] == result['search']['y'] for s in transitions['list-to-one-result']), transitions
    keys('Escape')
    eventually(state, lambda s: not s['loaded'], 'close application results')
    check('search field stays at half screen height; five rows, End reaches result 20, list resize fades')

    hypr('eval', 'hl.monitor({output=' + json.dumps(first) + ',mode="1920x1080@60",position="2000x0",scale=1.5})')
    eventually(lambda: hypr('monitors', data=True), lambda ms: any(m['name'] == first and m['scale'] == 1.5 for m in ms), 'fractional output')
    time.sleep(.2)
    result = open_launcher()
    centered(result, 720)
    assert result['surface']['x'] >= 8 and result['frame']['x'] + result['frame']['width'] <= 1280 - 8, result
    assert result['surface']['y'] == result['frame']['y'], result
    capture('launcher-native-scale-1.5')
    keys('Escape', 'j', 'Return')
    eventually(state, lambda s: not s['loaded'] and s['activations'] == 1, 'one activation')
    check('fractional scale keeps both frames on output; Enter activates exactly one selected clipboard item')
    assert not qml_errors(runtime_log(log)), runtime_log(log)
    return {'result': 'PASS', 'checks': checks, 'captures': captures, 'transitions': transitions, 'commands': commands, 'final': state(),
            'isolation': 'private Wayland, XDG and buses; clipboard, hardware and session fixtures'}
