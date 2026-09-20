#!/usr/bin/env python3
"""Smaller clock-colored bar icons: immutable release and guarded restoration of configuration files."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys, tempfile, time

HERE = Path(__file__).resolve().parent
PLAN = json.loads((HERE / 'plan.json').read_text())
BACKUP = Path(PLAN['backup'])
def digest(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest() if Path(p).exists() else None
def run(args, check=True, timeout=15):
    p = subprocess.run(args, text=True, capture_output=True, timeout=timeout)
    if check and p.returncode:
        raise RuntimeError(f'{args[0]} exit {p.returncode}: {p.stderr.strip() or p.stdout.strip()}')
    return p.stdout.strip()
def instances():
    value = run(['quickshell', 'list', '--all', '--json'])
    # Quickshell 0.3.1 prints prose, even with --json, when no instance runs.
    return [] if value == 'No running instances.' else json.loads(value)
def matching(entry): return [x for x in instances() if x['config_path'] == entry]
def until(predicate, timeout=12):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = predicate()
        if value: return value
        time.sleep(.2)
    raise RuntimeError('Timeout waiting for shell state')
def owner():
    value = run(['busctl', '--user', '--timeout=2', '--json=short', 'call',
                 'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                 'GetConnectionUnixProcessID', 's', 'org.freedesktop.Notifications'], check=False)
    return json.loads(value)['data'][0] if value else None
def assert_preserved():
    for path, expected in PLAN['preserved'].items():
        assert digest(path) == expected, f'Protected user configuration changed: {path}'
def idle_state():
    if run(['systemctl', '--user', 'is-active', 'hypridle.service'], check=False) != 'active':
        return None
    pid = int(run(['systemctl', '--user', 'show', '--property=MainPID', '--value', 'hypridle.service']))
    reply = run(['busctl', '--user', '--timeout=2', '--json=short', 'call',
                 'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus',
                 'GetConnectionUnixProcessID', 's', 'org.freedesktop.ScreenSaver'], check=False)
    if not reply or json.loads(reply)['data'][0] != pid:
        return None
    return {'pid': pid, 'active': True, 'screensaver_owner_verified': True}
def restart_idle():
    run(['systemctl', '--user', 'restart', 'hypridle.service'])
    return until(idle_state)
def stop(entry):
    for instance in matching(entry):
        run(['quickshell', 'kill', '--id', instance['id']])
    until(lambda: not matching(entry))
def atomic_copy(src, dest):
    dest = Path(dest)
    fd, name = tempfile.mkstemp(prefix='.putkin-', dir=dest.parent)
    os.close(fd)
    try:
        shutil.copy2(src, name)
        with open(name, 'rb') as f: os.fsync(f.fileno())
        os.replace(name, dest)
    finally:
        Path(name).unlink(missing_ok=True)
def start(command, logfile):
    with logfile.open('a') as output:
        subprocess.run(command, stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
                       start_new_session=True, timeout=20, check=True)
def restore():
    for path, record in PLAN['changes'].items():
        if digest(path) not in (record['before'], record['after']):
            raise RuntimeError(f'Plik zmieniony po przełączeniu; zachowano Twoje zmiany: {path}. Kopia: {BACKUP}')
    stop(PLAN['entry'])
    for index, (path, record) in enumerate(PLAN['changes'].items()):
        if digest(path) != record['before']:
            if record['before'] is None: Path(path).unlink(missing_ok=True)
            else: atomic_copy(BACKUP / 'before' / str(index), path)
    run(['hyprctl', 'reload'])
    errors = run(['hyprctl', 'configerrors'])
    if errors: raise RuntimeError(errors)
    restart_idle()
    if not matching(PLAN['old_entry']):
        start(PLAN['old_launch'], BACKUP / 'restore.log')
    old = until(lambda: matching(PLAN['old_entry']))[0]
    until(lambda: owner() == old['pid'])
    (BACKUP / 'restored.json').write_text(json.dumps({'instance': old, 'notification_pid': owner()}, indent=2) + '\n')
    print('Przywrócono poprzedni shell i jego autostart.')
def complete_switch():
    errors = run(['hyprctl', 'configerrors'])
    if errors: raise RuntimeError(errors)
    start(PLAN['launch'], BACKUP / 'launch.log')
    new = until(lambda: matching(PLAN['entry']))[0]
    until(lambda: owner() == new['pid'])
    assert len(instances()) == 1, 'More than one shell instance'
    until(lambda: 'putkin-bar' in run(['hyprctl', '-j', 'layers']) and 'putkin-wallpaper' in run(['hyprctl', '-j', 'layers']))
    layers = json.loads(run(['hyprctl', '-j', 'layers']))
    monitors = json.loads(run(['hyprctl', '-j', 'monitors']))
    for monitor in monitors:
        values = [v for level in layers[monitor['name']]['levels'].values() for v in level]
        bars = [v for v in values if v['namespace'] == 'putkin-bar' and v['pid'] == new['pid']]
        assert len(bars) == 1 and bars[0]['h'] == 32, bars
        assert len([v for v in values if v['namespace'] == 'putkin-wallpaper' and v['pid'] == new['pid']]) == 1
        assert not any(v['namespace'].startswith('quickshell-de:') for v in values)
    prefix = ['quickshell', 'ipc', '--path', PLAN['entry'], 'call']
    def panel_layers():
        value = json.loads(run(['hyprctl', '-j', 'layers']))
        return [(name, layer) for name, screen in value.items() for level in screen['levels'].values() for layer in level
                if layer['namespace'] == 'putkin-panel' and layer['pid'] == new['pid']]
    keyboard = until(lambda: (value if value['ready'] and not value['busy'] else None)
                     if (value := json.loads(run(prefix + ['actions', 'status']))) else None)
    assert keyboard['applied'] and not keyboard['error'], keyboard
    assert run(prefix + ['ui', 'openSettings']) == 'ok'
    settings_client = until(lambda: next((c for c in json.loads(run(['hyprctl', '-j', 'clients']))
        if c['pid'] == new['pid'] and c['title'] == 'Ustawienia'), None))
    assert settings_client['floating'], settings_client
    run(prefix + ['ui', 'closePanels'])
    until(lambda: not any(c['pid'] == new['pid'] and c['title'] == 'Ustawienia'
        for c in json.loads(run(['hyprctl', '-j', 'clients']))))
    bar_monitor = run(prefix + ['bar', 'focus'])
    assert bar_monitor in [m['name'] for m in monitors], bar_monitor
    run(prefix + ['bar', 'close'])
    caffeinate = json.loads(run(prefix + ['caffeinate', 'status']))
    assert caffeinate['mode'] == 'off' and not caffeinate['active'] and not caffeinate['busy'] and not caffeinate['error'], caffeinate
    before_audio = json.loads(run(prefix + ['audio', 'status']))
    panels = {}
    for target, method in [('ui', 'openAudio'), ('ui', 'openNotifications'), ('launcher', 'openCommands'), ('launcher', 'openClipboard'), ('launcher', 'open'), ('ui', 'openQuickSettings')]:
        assert run(prefix + [target, method]) == 'ok'
        try:
            shown = until(lambda: [value for value in panel_layers() if value[1]['alpha'] >= .99])
            focused = next(m for m in monitors if m['focused'])
            assert len(shown) == 1 and shown[0][0] == focused['name'], shown
            logical_width = round(focused['width'] / focused['scale'])
            expected_width = round((logical_width + min(640, logical_width - 16)) / 2) if target == 'launcher' else min(360, logical_width - 16) + 8
            assert shown[0][1]['w'] == expected_width, shown
            panels[method] = shown
            time.sleep(.3)
        finally:
            run(prefix + ['ui', 'closePanels'])
        until(lambda: not panel_layers())
    assert run(prefix + ['ui', 'toggleAudio']) == 'ok'
    until(lambda: panel_layers())
    assert run(prefix + ['ui', 'toggleAudio']) == 'ok'
    until(lambda: not panel_layers())
    after_audio = json.loads(run(prefix + ['audio', 'status']))
    assert before_audio == after_audio, 'Opening panels changed output state'
    live_log = run(['quickshell', 'log', '--no-color', '--id', new['id']])
    (BACKUP / 'verified.log').write_text(live_log + '\n')
    assert not any(word in live_log for word in ['WARN', 'ERROR', 'TypeError', 'ReferenceError', 'Traceback']), live_log
    audio = json.loads(run(prefix + ['audio', 'status']))
    brightness = json.loads(run(prefix + ['brightness', 'status']))
    session = json.loads(run(prefix + ['session', 'status']))
    assert digest(PLAN['keyboard']) == PLAN['keyboard_sha256'], 'Keyboard file changed'
    assert digest(PLAN['settings']) == PLAN['settings_sha256'], 'Settings unexpectedly changed'
    binds = json.loads(run(['hyprctl', '-j', 'binds']))
    selected_binds = []
    for mask, key, description in [(64, 'space', 'launcher'), (64, 'v', 'clipboard'), (65, 'semicolon', 'commands')]:
        selected = [b for b in binds if b.get('modmask') == mask and b.get('key', '').lower() == key]
        assert len(selected) == 1 and selected[0]['dispatcher'] == '__lua' and selected[0]['description'] == 'Putkin:' + description, selected
        selected_binds += selected
    actual = {str(p.relative_to(PLAN['release'])): digest(p) for p in Path(PLAN['release']).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
    assert actual == PLAN['manifest'], 'Published runtime changed'
    assert run(['chezmoi', 'status']) == PLAN['chezmoi_status_before'], 'Existing chezmoi difference changed'
    assert all(digest(path) == record['after'] for path, record in PLAN['changes'].items()), 'Configuration changed during activation'
    assert_preserved()
    hypridle = until(idle_state)
    assert session['capabilities']['lock']['available'], session
    result = {'hypridle': hypridle, 'auth_unchanged': True, 'chezmoi_status': run(['chezmoi', 'status']), 'bar_focus': bar_monitor, 'keyboard': keyboard, 'settings_window': settings_client, 'panel_ipc': panels, 'audio_toggle': True, 'audio_before': before_audio, 'audio_after': after_audio,
              'launcher_binds': selected_binds, 'instance': new, 'notification_pid': owner(), 'monitors': monitors,
              'layers': layers, 'caffeinate': caffeinate, 'audio': audio, 'brightness': brightness, 'session': session,
              'settings_unchanged': True, 'configerrors': errors, 'runtime_manifest_verified': True,
              'restore': str(BACKUP / 'restore'), 'runtime_files': PLAN['runtime_files']}
    (BACKUP / 'activated.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))

def apply():
    assert_preserved()
    assert idle_state(), 'Hypridle must be active before deployment'
    current = instances()
    assert len(current) == 1 and current[0]['id'] == PLAN['old_id'] and current[0]['pid'] == PLAN['old_pid'], current
    assert owner() == PLAN['old_pid'], 'Notification owner changed'
    old_caffeinate = json.loads(run(['quickshell', 'ipc', '--path', PLAN['old_entry'], 'call', 'caffeinate', 'status']))
    assert old_caffeinate['mode'] == 'off' and not old_caffeinate['active'], old_caffeinate
    assert digest(PLAN['keyboard']) == PLAN['keyboard_sha256'], 'Keyboard file changed'
    assert digest(PLAN['settings']) == PLAN['settings_sha256'], 'Settings changed'
    for path, record in PLAN['changes'].items():
        assert digest(path) == record['before'], f'Config changed: {path}'
        assert digest(record['source']) == record['after']
    release = Path(PLAN['release'])
    assert not release.exists() and not BACKUP.exists()
    BACKUP.mkdir(parents=True, mode=0o700)
    (BACKUP / 'before').mkdir(mode=0o700)
    (BACKUP / 'after').mkdir(mode=0o700)
    shutil.copy2(HERE / 'plan.json', BACKUP / 'plan.json')
    shutil.copy2(__file__, BACKUP / 'restore')
    (BACKUP / 'restore').chmod(0o700)
    for index, (path, record) in enumerate(PLAN['changes'].items()):
        if Path(path).exists(): shutil.copy2(path, BACKUP / 'before' / str(index))
        shutil.copy2(record['source'], BACKUP / 'after' / str(index))
    release.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.stage-', dir=release.parent))
    try:
        shutil.copytree(HERE / 'runtime', stage, dirs_exist_ok=True)
        actual = {str(p.relative_to(stage)): digest(p) for p in stage.rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc'}
        assert actual == PLAN['manifest'], 'Incomplete runtime package'
        os.replace(stage, release)
    finally:
        if stage.exists(): shutil.rmtree(stage)
    try:
        # All code is complete before configuration changes or process handoff.
        for index, path in enumerate(PLAN['changes']):
            atomic_copy(BACKUP / 'after' / str(index), path)
        run(['hyprctl', 'reload'])
        errors = run(['hyprctl', 'configerrors'])
        if errors: raise RuntimeError(errors)
        stop(PLAN['old_entry'])
        until(lambda: owner() is None)
        restart_idle()
        complete_switch()
    except BaseException:
        restore()
        raise

def retry():
    current = matching(PLAN['old_entry'])
    assert len(instances()) == 1 and len(current) == 1 and owner() == current[0]['pid']
    assert digest(PLAN['keyboard']) == PLAN['keyboard_sha256'], 'Keyboard file changed'
    assert digest(PLAN['settings']) == PLAN['settings_sha256']
    actual = {str(p.relative_to(PLAN['release'])): digest(p) for p in Path(PLAN['release']).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
    assert actual == PLAN['manifest'], 'Published runtime changed'
    for index, (path, record) in enumerate(PLAN['changes'].items()):
        assert digest(path) == record['before'], f'Config changed: {path}'
        assert digest(BACKUP / 'before' / str(index)) == record['before']
        assert digest(BACKUP / 'after' / str(index)) == record['after']
    shutil.copy2(__file__, BACKUP / 'restore')
    (BACKUP / 'restore').chmod(0o700)
    try:
        for index, path in enumerate(PLAN['changes']):
            atomic_copy(BACKUP / 'after' / str(index), path)
        run(['hyprctl', 'reload'])
        errors = run(['hyprctl', 'configerrors'])
        if errors: raise RuntimeError(errors)
        stop(PLAN['old_entry'])
        until(lambda: owner() is None)
        restart_idle()
        complete_switch()
    except BaseException:
        restore()
        raise

if __name__ == '__main__':
    if sys.argv[1:] == ['--retry']: retry()
    elif sys.argv[1:] == ['--apply']: apply()
    elif not sys.argv[1:]: restore()
    else: raise SystemExit('Usage: restore')
