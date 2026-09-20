"""Verify native session package and rollback using only temporary files/fake commands."""
import importlib.util
import json
from pathlib import Path
import re
import tempfile

ROOT = Path('/home/attntd/projects/putkin')
STAGE = Path('/tmp/putkin-native-session-update')
spec = importlib.util.spec_from_file_location('activation', STAGE/'activate.py')
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
plan = module.PLAN
actual = {str(p.relative_to(STAGE/'runtime')):module.digest(p) for p in (STAGE/'runtime').rglob('*') if p.is_file()}
assert actual == plan['manifest']
assert all(module.digest(ROOT/relative) == checksum for relative,checksum in actual.items())
assert all(not (STAGE/'runtime'/relative).exists() for relative in plan['deleted_runtime'])
normalize = lambda text: re.sub(r'/home/attntd/\.local/share/putkin/releases/[^/\s"\']+', '<release>', text)
for name,record in plan['changes'].items():
    assert module.digest(name) == record['before']
    assert module.digest(record['source']) == record['after']
    assert normalize(Path(name).read_text()) == normalize(Path(record['source']).read_text())
for path,checksum in plan['preserved'].items(): assert module.digest(path) == checksum
assert module.digest(plan['idle_source']) == plan['idle_source_sha256']

original_run = module.run
for target_mode in ('off','background','presentation'):
    state = {'mode':'background' if target_mode=='off' else 'off','busy':False,'error':''}; actions=[]
    def fake_ipc(args, **kwargs):
        if args[-1]=='status': return json.dumps(state)
        assert args[-2] in ('setMode','setEnabled'), args
        actions.append(args[-2:]); state['mode']='off' if args[-2]=='setEnabled' else args[-1]
        return 'accepted'
    module.run=fake_ipc
    assert module.resume_caffeinate('test.qml',target_mode)['mode']==target_mode
    assert module.resume_caffeinate('test.qml',target_mode)['mode']==target_mode
    assert len(actions)==1
module.run=original_run

with tempfile.TemporaryDirectory(prefix='pk-native-rollback-') as directory:
    base=Path(directory); module.BACKUP=base/'backup'; (module.BACKUP/'before').mkdir(parents=True)
    changes={}
    for index,(name,record) in enumerate(plan['changes'].items()):
        target=base/str(index); target.write_bytes(Path(record['source']).read_bytes())
        (module.BACKUP/'before'/str(index)).write_bytes(Path(name).read_bytes()); changes[str(target)]=dict(record)
    idle_source=base/'symlink_hypridle.service'
    (module.BACKUP/'hypridle-source').write_bytes(Path(plan['idle_source']).read_bytes())
    module.PLAN=dict(plan,changes=changes,idle_source=str(idle_source))
    stopped=[]; commands=[]; modes=[]
    module.stop=lambda entry:stopped.append(entry)
    def fake_run(args,**kwargs):
        commands.append(args)
        return 'false' if args == ['hyprctl','locked'] else ''
    module.run=fake_run
    module.matching=lambda entry:[{'pid':123,'config_path':plan['old_entry']}] if entry==plan['old_entry'] else []
    module.owner=lambda:123
    module.idle_state=lambda:{'active':True}
    module.caffeinate_state=lambda entry:{'mode':'presentation'}
    def resume_mode(entry,mode): modes.append(mode); return {'mode':mode}
    module.resume_caffeinate=resume_mode
    module.restore()
    assert all(module.digest(path)==record['before'] for path,record in changes.items())
    assert module.digest(idle_source)==plan['idle_source_sha256']
    assert ['systemctl','--user','enable','--now','hypridle.service'] in commands
    module.restore(); module.restore('background')
    assert modes==['presentation','presentation','background']
    first=Path(next(iter(changes))); first.write_text(first.read_text()+'\n-- later edit\n')
    count=len(stopped)
    try: module.restore()
    except RuntimeError as e: assert 'Plik zmieniony' in str(e)
    else: raise AssertionError('Rollback overwrote later edits')
    assert len(stopped)==count and first.read_text().endswith('-- later edit\n')
    # The restart guard must refuse a locked session before stopping anything.
    module.run=lambda args,**kw:'true' if args==['hyprctl','locked'] else ''
    try: module.restore()
    except AssertionError as e: assert 'zablokowanej' in str(e)
    else: raise AssertionError('Rollback restarted a locked shell')
    assert len(stopped)==count
print(f'PASS: {len(actual)} packaged runtime files equal checked sources; {len(plan["changes"])} config changes replace only release paths; '
      'Caffeinate modes preserved; rollback restores files and Hypridle autostart; repeat rollback, later-edit and locked-session guards pass.')
