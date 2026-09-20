"""Prepare the isolated Signal icon correction; preserve concurrent session work and desktop changes."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path('/home/attntd/projects/putkin')
BUILD = Path('/tmp/putkin-signal-chat-validation')
STAGE = Path('/tmp/putkin-signal-chat-update')
EVIDENCE = ROOT / 'docs/evidence'
OLD = json.loads((EVIDENCE / 'charging-material-activation-plan.json').read_text())


def digest(path):
    path = Path(path)
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


assert not STAGE.exists()
STAGE.mkdir(mode=0o700)
runtime = STAGE / 'runtime'
runtime.mkdir()
isolation = json.loads((EVIDENCE / 'signal-chat-isolation.json').read_text())
assert str(Path(OLD['entry']).parent) == isolation['base_release']
for name, checksum in isolation['changed_checksums'].items():
    assert digest(ROOT / name) == checksum == digest(BUILD / name), name
paths = [BUILD / 'shell.qml', BUILD / 'scripts/lock-session']
for directory in ['assets', 'components', 'config', 'core', 'modules', 'services']:
    paths.extend(p for p in (BUILD / directory).rglob('*')
                 if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
manifest = {}
for source in sorted(paths):
    assert not source.is_symlink(), source
    relative = source.relative_to(BUILD)
    target = runtime / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    manifest[str(relative)] = digest(target)
changed = sorted(name for name in manifest if manifest[name] != OLD['manifest'].get(name))
removed = {'assets/material/putkin_signal.svg'}
added = {'assets/material/chat_bubble.svg', 'services/SignalTrayState.qml'}
modified = {'assets/material/Paths.js', 'assets/material/README.md', 'assets/material/manifest.json',
            'core/Icons.js', 'modules/tray/TrayButton.qml'}
assert set(manifest) - set(OLD['manifest']) == added, 'Unexpected added files'
assert set(OLD['manifest']) - set(manifest) == removed, 'Unexpected removed files'
assert set(changed) == modified | added, changed
assert len(manifest) == 261, len(manifest)
release_hash = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()[:12]
release = Path('/home/attntd/.local/share/putkin/releases') / ('20260920-signal-chat-' + release_hash)
entry = str(release / 'shell.qml')
old_entry = OLD['entry']
old_release = str(Path(old_entry).parent)
old_actual = {str(p.relative_to(old_release)): digest(p) for p in Path(old_release).rglob('*')
              if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc'}
assert old_actual == OLD['manifest'], 'Active runtime differs from previous verified release'
current = json.loads(subprocess.check_output(['quickshell', 'list', '--all', '--json'], text=True))
assert len(current) == 1 and current[0]['config_path'] == old_entry, current
chezmoi_status = subprocess.check_output(['chezmoi', 'status'], text=True).strip()
# Preserve the existing status, including unrelated live changes in Zen.
changes = {}
for relative in ['hyprland.lua', 'autostart.lua', 'modules/system_binds.lua', 'hypridle.conf']:
    target = Path('/home/attntd/.config/hypr') / relative
    chezmoi = Path(subprocess.check_output(['chezmoi', 'source-path', str(target)], text=True).strip())
    # Preserve each file independently: the user has a live-only Zen window rule.
    for path in [target, chezmoi]:
        assert not path.is_symlink(), path
        before = path.read_text()
        after = before.replace(old_release, str(release))
        if relative in ('modules/system_binds.lua', 'hypridle.conf'):
            after, count = re.subn(r'/home/attntd/\.local/share/putkin/releases/[^/\s"\']+/scripts/lock-session',
                                   str(release / 'scripts/lock-session'), after)
            assert count == 1, (path, count)
        assert before != after, path
        prepared = STAGE / ('config-' + str(len(changes)))
        shutil.copy2(path, prepared)
        prepared.write_text(after)
        changes[str(path)] = {'before': digest(path), 'after': digest(prepared), 'source': str(prepared)}
launch = OLD['launch'][:-1] + [entry]
settings = '/home/attntd/.config/putkin/settings.json'
keyboard = '/home/attntd/.config/putkin/keyboard.json'
preserved = ['/home/attntd/.config/putkin/hyprlock-auth.conf', '/home/attntd/.config/hypr/hyprlock.conf',
             '/home/attntd/.config/quickshell/scripts/caffeinate-idle']
caffeinate = json.loads(subprocess.check_output(['quickshell', 'ipc', '--path', old_entry,
    'call', 'caffeinate', 'status'], text=True))
assert not caffeinate['busy'] and not caffeinate['error'], caffeinate
plan = {
    'release': str(release), 'entry': entry, 'old_entry': old_entry,
    'backup': '/home/attntd/.local/state/putkin/update-' + release.name,
    'manifest': manifest, 'runtime_files': len(manifest), 'changed_runtime': changed, 'deleted_runtime': sorted(removed), 'changes': changes,
    'settings': settings, 'settings_sha256': digest(settings),
    'keyboard': keyboard, 'keyboard_sha256': digest(keyboard),
    'preserved': {path: digest(path) for path in preserved},
    'chezmoi_status_before': chezmoi_status,
    'launch': launch, 'old_launch': OLD['launch'],
    'isolated_build': str(BUILD), 'isolation': isolation, 'caffeinate_before': caffeinate,
    'old_id': current[0]['id'], 'old_pid': current[0]['pid'],
}
for target in [STAGE / 'plan.json', EVIDENCE / 'signal-chat-activation-plan.json']:
    target.write_text(json.dumps(plan, indent=2) + '\n')
print(json.dumps({'release': str(release), 'runtime_files': len(manifest), 'changed_runtime': changed,
                  'configurations': list(changes), 'preserved_chezmoi_status': chezmoi_status,
                  'restore': plan['backup'] + '/restore'}, indent=2))
