from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path('/home/attntd/projects/putkin')
STAGE = Path('/tmp/putkin-monochrome-icons-update')
EVIDENCE = ROOT / 'docs/evidence'
OLD = json.loads((EVIDENCE / 'launcher-icons-activation-plan.json').read_text())

def digest(path):
    path = Path(path)
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None

assert not STAGE.exists()
STAGE.mkdir(mode=0o700)
runtime = STAGE / 'runtime'
runtime.mkdir()
paths = [ROOT / 'shell.qml', ROOT / 'scripts/lock-session']
for directory in ['assets', 'components', 'config', 'core', 'modules', 'services']:
    paths.extend(p for p in (ROOT / directory).rglob('*')
                 if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
manifest = {}
for source in sorted(paths):
    assert not source.is_symlink(), source
    relative = source.relative_to(ROOT)
    target = runtime / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    manifest[str(relative)] = digest(target)
assert set(manifest) - set(OLD['manifest']) == {'components/ApplicationIcon.qml'}
assert set(OLD['manifest']) <= set(manifest)
changed = [name for name in manifest if manifest[name] != OLD['manifest'].get(name)]
assert set(changed) == {'components/ApplicationIcon.qml', 'components/qmldir', 'core/Theme.qml', 'modules/launcher/LauncherView.qml', 'modules/tray/TrayButton.qml'}, changed
print('Changed runtime files:', ', '.join(changed))
release_hash = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()[:12]
release = Path('/home/attntd/.local/share/putkin/releases') / ('20260920-monochrome-icons-' + release_hash)
entry = str(release / 'shell.qml')
old_entry = OLD['entry']
old_release = str(Path(old_entry).parent)
current = json.loads(subprocess.check_output(['quickshell', 'list', '--all', '--json'], text=True))
assert len(current) == 1 and current[0]['config_path'] == old_entry, current
assert subprocess.check_output(['chezmoi', 'status'], text=True).strip() == ''
changes = {}
for relative in ['hyprland.lua', 'autostart.lua', 'modules/system_binds.lua']:
    target = Path('/home/attntd/.config/hypr') / relative
    chezmoi = Path(subprocess.check_output(['chezmoi', 'source-path', str(target)], text=True).strip())
    assert target.read_bytes() == chezmoi.read_bytes()
    for path in [target, chezmoi]:
        assert not path.is_symlink(), path
        before = path.read_text()
        assert old_release in before, path
        after = before.replace(old_release, str(release))
        prepared = STAGE / ('config-' + str(len(changes)))
        shutil.copy2(path, prepared)
        prepared.write_text(after)
        changes[str(path)] = {'before': digest(path), 'after': digest(prepared), 'source': str(prepared)}
launch = OLD['launch'][:-1] + [entry]
settings = '/home/attntd/.config/putkin/settings.json'
keyboard = '/home/attntd/.config/putkin/keyboard.json'
plan = {
    'release': str(release), 'entry': entry, 'old_entry': old_entry,
    'backup': '/home/attntd/.local/state/putkin/update-' + release.name,
    'manifest': manifest, 'runtime_files': len(manifest), 'changes': changes,
    'settings': settings, 'settings_sha256': digest(settings),
    'keyboard': keyboard, 'keyboard_sha256': digest(keyboard),
    'launch': launch, 'old_launch': OLD['launch'],
    'old_id': current[0]['id'], 'old_pid': current[0]['pid'],
}
for target in [STAGE / 'plan.json', EVIDENCE / 'monochrome-icons-activation-plan.json']:
    target.write_text(json.dumps(plan, indent=2) + '\n')
activate = (EVIDENCE / 'launcher-icons-activate.py').read_text()
activate = activate.replace('Local launcher application icons:', 'Local monochrome launcher and Signal icons:')
activate = activate.replace("('launcher', 'openClipboard'),", "('launcher', 'openClipboard'), ('launcher', 'open'),")
for target in [STAGE / 'activate.py', EVIDENCE / 'monochrome-icons-activate.py']:
    target.write_text(activate)
    target.chmod(0o700)
print(json.dumps({'release': str(release), 'runtime_files': len(manifest), 'changes': list(changes), 'restore': plan['backup'] + '/restore'}, indent=2))
