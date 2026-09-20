"""Verify packaging and rollback without contacting the running desktop."""
import importlib.util
import json
from pathlib import Path
import re
import tempfile

ROOT = Path('/home/attntd/projects/putkin')
STAGE = Path('/tmp/putkin-bar-icons-update')
spec = importlib.util.spec_from_file_location('activation', STAGE/'activate.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
plan = module.PLAN
actual = {str(p.relative_to(STAGE/'runtime')): module.digest(p) for p in (STAGE/'runtime').rglob('*') if p.is_file()}
assert actual == plan['manifest']
assert all(module.digest(ROOT/relative) == checksum for relative, checksum in actual.items())
normalize = lambda text: re.sub(r'/home/attntd/\.local/share/putkin/releases/[^/\s"\']+', '<release>', text)
for name, record in plan['changes'].items():
    assert module.digest(name) == record['before']
    assert module.digest(record['source']) == record['after']
    assert normalize(Path(name).read_text()) == normalize(Path(record['source']).read_text())
for path, checksum in plan['preserved'].items():
    assert module.digest(path) == checksum

with tempfile.TemporaryDirectory(prefix='pk-bar-icons-restore-') as directory:
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
    module.restore()
    assert all(module.digest(path) == record['before'] for path, record in changes.items())
    module.restore()
    assert len(idle_restarts) == 2
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

print(f'PASS: {len(actual)} runtime files match sources; {len(plan["changes"])} configurations change only release paths; '
      'auth/settings ownership preserved; rollback, repeated rollback and later-edit protection passed on temporary files.')
