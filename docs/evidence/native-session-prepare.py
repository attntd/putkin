"""Prepare the native session migration against the current verified live release."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path('/home/attntd/projects/putkin')
STAGE = Path('/tmp/putkin-native-session-update')
EVIDENCE = ROOT / 'docs/evidence'
def run(args): return subprocess.check_output(args, text=True).strip()
def digest(path):
    path = Path(path)
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None

current = json.loads(run(['quickshell', 'list', '--all', '--json']))
assert len(current) == 1, current
old_entry = current[0]['config_path']
old_path = next(p for p in EVIDENCE.glob('*activation-plan.json') if json.loads(p.read_text()).get('entry') == old_entry)
OLD = json.loads(old_path.read_text())
old_release = str(Path(old_entry).parent)
actual = {str(p.relative_to(old_release)): digest(p) for p in Path(old_release).rglob('*')
          if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc'}
assert actual == OLD['manifest'], 'Live release changed'
assert not STAGE.exists()
STAGE.mkdir(mode=0o700)
runtime = STAGE/'runtime'; runtime.mkdir()
paths = [ROOT/'shell.qml', ROOT/'scripts/lock-session']
for directory in ['assets','components','config','core','modules','services']:
    paths.extend(p for p in (ROOT/directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
manifest = {}
for source in sorted(paths):
    assert not source.is_symlink()
    relative = source.relative_to(ROOT)
    target = runtime/relative; target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source,target); manifest[str(relative)] = digest(target)
changed = sorted(k for k in manifest if manifest[k] != OLD['manifest'].get(k))
removed = sorted(set(OLD['manifest'])-set(manifest))
allowed = {'shell.qml','scripts/lock-session','services/SessionBackend.qml','services/SessionIpc.qml','services/SessionService.qml',
           'services/BrightnessService.qml','services/qmldir','services/session_backend.py','services/IdleBackend.qml',
           'services/IdleService.qml','services/LockService.qml','services/PamBackend.qml',
           'config/pam.d/putkin-password','config/pam.d/putkin-fingerprint',
           'modules/lock/qmldir','modules/lock/LockHost.qml','modules/lock/LockView.qml'}
assert set(changed) == allowed, changed
assert set(removed) == {'config/hypridle.example.conf','config/hyprlock.example.conf','services/session_lock.py','services/lock_appearance.py','services/lock_indicator.py'}, removed
release_hash = hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest()[:12]
release = Path('/home/attntd/.local/share/putkin/releases')/('20260920-native-session-'+release_hash)
changes = {}
for relative in ['hyprland.lua','autostart.lua','modules/system_binds.lua']:
    target = Path('/home/attntd/.config/hypr')/relative
    source = Path(run(['chezmoi','source-path',str(target)]))
    for path in [target,source]:
        assert not path.is_symlink()
        before = path.read_text(); after = before.replace(old_release,str(release))
        assert before != after, path
        prepared = STAGE/('config-'+str(len(changes)))
        shutil.copy2(path,prepared); prepared.write_text(after)
        changes[str(path)] = {'before':digest(path),'after':digest(prepared),'source':str(prepared)}
preserved = dict(OLD['preserved'])
for target in [Path('/home/attntd/.config/hypr/hypridle.conf')]:
    for path in [target,Path(run(['chezmoi','source-path',str(target)]))]:
        preserved[str(path)] = digest(path)
for path in preserved: assert digest(path) == preserved[path]
launch = OLD['launch'][:-1] + [str(release/'shell.qml')]
caffeinate = json.loads(run(['quickshell','ipc','--path',old_entry,'call','caffeinate','status']))
assert not caffeinate['busy'] and not caffeinate['error']
idle_enabled = run(['systemctl','--user','is-enabled','hypridle.service'])
assert idle_enabled == 'enabled', idle_enabled
assert run(['systemctl','--user','is-active','hypridle.service']) == 'active'
idle_link = Path('/home/attntd/.config/systemd/user/graphical-session.target.wants/hypridle.service')
assert idle_link.is_symlink() and str(idle_link.readlink()) == '/usr/lib/systemd/user/hypridle.service'
idle_source = Path(run(['chezmoi','source-path',str(idle_link)]))
assert idle_source.read_text().strip() == str(idle_link.readlink())
locked_during_preparation = run(['hyprctl','locked'])
plan = {'release':str(release),'entry':str(release/'shell.qml'),'old_entry':old_entry,
        'backup':'/home/attntd/.local/state/putkin/update-'+release.name,
        'manifest':manifest,'runtime_files':len(manifest),'changed_runtime':changed,'deleted_runtime':removed,'changes':changes,
        'settings':OLD['settings'],'settings_sha256':digest(OLD['settings']),
        'keyboard':OLD['keyboard'],'keyboard_sha256':digest(OLD['keyboard']),
        'preserved':preserved,'chezmoi_status_before':run(['chezmoi','status']),
        'launch':launch,'old_launch':OLD['launch'],'old_id':current[0]['id'],'old_pid':current[0]['pid'],
        'caffeinate_before':caffeinate,'hypridle_enabled_before':idle_enabled,
        'idle_source':str(idle_source),'idle_source_sha256':digest(idle_source),
        'locked_during_preparation':locked_during_preparation}
for target in [STAGE/'plan.json',EVIDENCE/'native-session-activation-plan.json']:
    target.write_text(json.dumps(plan,indent=2)+'\n')
shutil.copy2(EVIDENCE/'native-session-activate.py',STAGE/'activate.py')
print(json.dumps({'release':str(release),'runtime_files':len(manifest),'changed':changed,'removed':removed,
                  'configurations':list(changes),'caffeinate':caffeinate,'restore':plan['backup']+'/restore'},indent=2))
