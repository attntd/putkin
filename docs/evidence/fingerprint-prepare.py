"""Prepare the fingerprint release and narrowly update its live entry points."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path('/home/attntd/projects/putkin')
STAGE = Path('/tmp/putkin-fingerprint-update')
EVIDENCE = ROOT / 'docs/evidence'
OLD = json.loads((EVIDENCE / 'monochrome-icons-activation-plan.json').read_text())


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
assert set(manifest) - set(OLD['manifest']) == {'services/lock_indicator.py'}
assert set(OLD['manifest']) <= set(manifest)
changed = [name for name in manifest if manifest[name] != OLD['manifest'].get(name)]
assert set(changed) == {'config/hyprlock.example.conf', 'services/lock_appearance.py',
                        'services/lock_indicator.py', 'services/session_lock.py'}, changed
release_hash = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()[:12]
release = Path('/home/attntd/.local/share/putkin/releases') / ('20260920-fingerprint-' + release_hash)
entry = str(release / 'shell.qml')
old_entry = OLD['entry']
old_release = str(Path(old_entry).parent)
old_actual = {str(p.relative_to(old_release)): digest(p) for p in Path(old_release).rglob('*')
              if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc'}
assert old_actual == OLD['manifest'], 'Active runtime differs from previous verified release'
current = json.loads(subprocess.check_output(['quickshell', 'list', '--all', '--json'], text=True))
assert len(current) == 1 and current[0]['config_path'] == old_entry, current
chezmoi_status = subprocess.check_output(['chezmoi', 'status'], text=True).strip()
assert chezmoi_status == 'MM .config/hypr/hyprland.lua', chezmoi_status
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
plan = {
    'release': str(release), 'entry': entry, 'old_entry': old_entry,
    'backup': '/home/attntd/.local/state/putkin/update-' + release.name,
    'manifest': manifest, 'runtime_files': len(manifest), 'changed_runtime': changed, 'changes': changes,
    'settings': settings, 'settings_sha256': digest(settings),
    'keyboard': keyboard, 'keyboard_sha256': digest(keyboard),
    'preserved': {path: digest(path) for path in preserved},
    'chezmoi_status_before': chezmoi_status,
    'launch': launch, 'old_launch': OLD['launch'],
    'old_id': current[0]['id'], 'old_pid': current[0]['pid'],
}
for target in [STAGE / 'plan.json', EVIDENCE / 'fingerprint-activation-plan.json']:
    target.write_text(json.dumps(plan, indent=2) + '\n')
print(json.dumps({'release': str(release), 'runtime_files': len(manifest), 'changed_runtime': changed,
                  'configurations': list(changes), 'preserved_chezmoi_status': chezmoi_status,
                  'restore': plan['backup'] + '/restore'}, indent=2))
