#!/usr/bin/env python3
"""Local visual correction: immutable release and guarded restoration of six configuration files."""
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
    run(['systemctl', '--user', 'restart', 'hypridle.service'])
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
    layers = json.loads(run(['hyprctl', '-j', 'layers']))
    monitors = json.loads(run(['hyprctl', '-j', 'monitors']))
    for monitor in monitors:
        values = [v for level in layers[monitor['name']]['levels'].values() for v in level]
        bars = [v for v in values if v['namespace'] == 'putkin-bar' and v['pid'] == new['pid']]
        assert len(bars) == 1 and bars[0]['h'] == 32, bars
        assert not any(v['namespace'].startswith('quickshell-de:') for v in values)
    prefix = ['quickshell', 'ipc', '--path', PLAN['entry'], 'call']
    audio = json.loads(run(prefix + ['audio', 'status']))
    brightness = json.loads(run(prefix + ['brightness', 'status']))
    session = json.loads(run(prefix + ['session', 'status']))
    assert digest(PLAN['settings']) == PLAN['settings_sha256'], 'Settings unexpectedly changed'
    result = {'instance': new, 'notification_pid': owner(), 'monitors': monitors,
              'layers': layers, 'audio': audio, 'brightness': brightness, 'session': session,
              'settings_unchanged': True, 'configerrors': errors,
              'restore': str(BACKUP / 'restore'), 'runtime_files': PLAN['runtime_files']}
    (BACKUP / 'activated.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))

def apply():
    current = instances()
    assert len(current) == 1 and current[0]['id'] == PLAN['old_id'] and current[0]['pid'] == PLAN['old_pid'], current
    assert owner() == PLAN['old_pid'], 'Notification owner changed'
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
        actual = {str(p.relative_to(stage)): digest(p) for p in stage.rglob('*') if p.is_file() and p.name != 'manifest.json'}
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
        run(['systemctl', '--user', 'restart', 'hypridle.service'])
        complete_switch()
    except BaseException:
        restore()
        raise

if __name__ == '__main__':
    if sys.argv[1:] == ['--apply']: apply()
    elif not sys.argv[1:]: restore()
    else: raise SystemExit('Usage: restore')
