"""Verify packaging and rollback without contacting the running desktop."""
import importlib.util
import json
from pathlib import Path
import re
import tempfile

ROOT = Path('/home/attntd/projects/putkin')
STAGE = Path('/tmp/putkin-signal-chat-update')
spec = importlib.util.spec_from_file_location('activation', STAGE/'activate.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
plan = module.PLAN
actual = {str(p.relative_to(STAGE/'runtime')): module.digest(p) for p in (STAGE/'runtime').rglob('*') if p.is_file()}
assert actual == plan['manifest']
assert all(module.digest(Path(plan['isolated_build'])/relative) == checksum for relative, checksum in actual.items())
assert all(module.digest(ROOT/relative) == checksum for relative, checksum in plan['isolation']['changed_checksums'].items())
assert all(relative not in actual for relative in plan['isolation']['removed_runtime'])
normalize = lambda text: re.sub(r'/home/attntd/\.local/share/putkin/releases/[^/\s"\']+', '<release>', text)
for name, record in plan['changes'].items():
    assert module.digest(name) == record['before']
    assert module.digest(record['source']) == record['after']
    assert normalize(Path(name).read_text()) == normalize(Path(record['source']).read_text())
for path, checksum in plan['preserved'].items():
    assert module.digest(path) == checksum

original_run = module.run
for target_mode in ('off', 'background', 'presentation'):
    state = {'mode': 'background' if target_mode == 'off' else 'off', 'busy': False, 'error': ''}
    actions = []
    def fake_ipc(args, **kwargs):
        if args[-1] == 'status':
            return json.dumps(state)
        assert args[-2] in ('setMode', 'setEnabled'), args
        actions.append(args[-2:])
        state['mode'] = 'off' if args[-2] == 'setEnabled' else args[-1]
        return 'accepted'
    module.run = fake_ipc
    assert module.resume_caffeinate('test.qml', target_mode)['mode'] == target_mode
    assert module.resume_caffeinate('test.qml', target_mode)['mode'] == target_mode
    assert len(actions) == 1, actions
module.run = original_run

with tempfile.TemporaryDirectory(prefix='pk-signal-chat-restore-') as directory:
    base = Path(directory)
    module.BACKUP = base/'backup'
    (module.BACKUP/'before').mkdir(parents=True)
    changes = {}
    for index, (name, record) in enumerate(plan['changes'].items()):
        target = base/str(index)
        target.write_bytes(Path(record['source']).read_bytes())
        (module.BACKUP/'before'/str(index)).write_bytes(Path(name).read_bytes())
        changes[str(target)] = dict(record)
    module.PLAN = dict(plan, changes=changes)
    stops = []
    idle_restarts = []
    module.stop = lambda entry: stops.append(entry)
    module.run = lambda *args, **kwargs: ''
    module.matching = lambda entry: [{'pid': 123, 'config_path': plan['old_entry']}]
    module.owner = lambda: 123
    module.restart_idle = lambda: idle_restarts.append(True)
    restored_modes = []
    module.caffeinate_state = lambda entry: {'mode': 'presentation'}
    def restore_mode(entry, mode):
        restored_modes.append(mode)
        return {'mode': mode}
    module.resume_caffeinate = restore_mode
    module.restore()
    assert all(module.digest(path) == record['before'] for path, record in changes.items())
    module.restore()
    assert len(idle_restarts) == 2
    assert restored_modes == ['presentation', 'presentation']
    module.restore('background')  # Automatic rollback restores the pre-switch mode.
    assert restored_modes[-1] == 'background'
    first = Path(next(iter(changes)))
    first.write_text(first.read_text() + '\n-- later user edit\n')
    before = len(stops)
    try:
        module.restore()
    except RuntimeError as error:
        assert 'Plik zmieniony' in str(error)
    else:
        raise AssertionError('Rollback overwrote a later edit')
    assert len(stops) == before
    assert first.read_text().endswith('-- later user edit\n')

print(f'PASS: {len(actual)} runtime files match the verified base plus the Signal source overlay; {len(plan["changes"])} configurations change only release paths; '
      'auth/settings ownership preserved; all three Caffeinate modes and idempotent restoration passed; '
      'rollback, repeated rollback and later-edit protection passed on temporary files.')
