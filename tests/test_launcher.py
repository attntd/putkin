"""Behavior of launcher I/O with private state and no host display."""
import asyncio
import base64
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('launcher_backend', ROOT / 'services/launcher_backend.py')
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


class HistoryTests(unittest.TestCase):
    def test_private_atomic_mru_roundtrip_and_limit(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'state/launcher.json'
            history = backend.History(path)
            for index in range(105):
                self.assertEqual(history.record(dict(kind='application', id=str(index))), '')
            history.record(dict(kind='file', id='/home/test/a b'))
            history.record(dict(kind='application', id='104'))
            loaded = backend.History(path)
            self.assertEqual(loaded.records, history.records)
            self.assertEqual(len(loaded.records), 100)
            self.assertEqual(loaded.records[0]['id'], '104')
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(path.parent.stat().st_mode & 0o777, 0o700)

    def test_clipboard_never_persisted_and_foreign_history_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'launcher.json'
            history = backend.History(path)
            history.record(dict(kind='clipboard', id='123', preview='secret'))
            self.assertEqual(json.loads(path.read_text())['records'], [])
            for content in ['broken', '[]', '{"schemaVersion":2,"records":[]}']:
                path.write_text(content)
                history = backend.History(path)
                self.assertTrue(history.error)
                history.record(dict(kind='application', id='kitty'))
                self.assertEqual(path.read_text(), content)


class BackendTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='pk-launcher-unit-')
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'; self.bin.mkdir()
        for name in ['wl-copy', 'xdg-open', 'fake-app', 'kitty']:
            target = self.bin / name
            target.write_bytes((ROOT / 'tests/launcher_tools.py').read_bytes()); target.chmod(0o700)
        self.env = dict(PATH=str(self.bin) + ':/usr/bin:/bin', HOME=str(self.root), XDG_RUNTIME_DIR=str(self.root),
                        XDG_CONFIG_HOME=str(self.root), PUTKIN_LAUNCHER_FIXTURE=str(self.root))
        self.patch = patch.dict(os.environ, self.env, clear=True); self.patch.start()
        self.worker = backend.Worker(self.root, self.root / 'state/launcher.json', self.root)
        self.events = []
        self.worker.emit = lambda **event: self.events.append(event)

    async def asyncTearDown(self):
        await self.worker.cancel_preview()
        if self.worker.copy_owner and self.worker.copy_owner.returncode is None:
            self.worker.copy_owner.kill(); await self.worker.copy_owner.wait()
        self.patch.stop(); self.temp.cleanup()

    async def test_real_fd_literal_paths_limits_and_no_shell(self):
        name = 'notes $(touch INJECTED) with spaces.md'
        (self.root / name).write_text('fixture')
        await self.worker.search(dict(revision=1, query='$(touch INJECTED)'))
        self.assertEqual(self.events[-1]['entries'], [str(self.root / name)])
        self.assertFalse((self.root / 'INJECTED').exists())
        for index in range(120): (self.root / f'note-{index}.md').touch()
        await self.worker.search(dict(revision=2, query='note-'))
        self.assertEqual(len(self.events[-1]['entries']), 100)
        await self.worker.search(dict(revision=3, query='does-not-exist'))
        self.assertEqual(self.events[-1]['entries'], [])
        with patch.dict(os.environ, {'PATH': str(self.bin)}):
            await self.worker.search(dict(revision=4, query='missing'))
        self.assertTrue(self.events[-1]['error'])

    async def test_search_timeout_and_cancellation_reap_process(self):
        slow = self.bin / 'fd'
        slow.write_text('#!/usr/bin/python3\nimport os,signal\nfrom pathlib import Path\nPath(os.environ["PUTKIN_LAUNCHER_FIXTURE"]+"/pid").write_text(str(os.getpid()))\nsignal.pause()\n'); slow.chmod(0o700)
        task = asyncio.create_task(self.worker.search(dict(revision=1, query='test')))
        for _ in range(100):
            if (self.root / 'pid').exists(): break
            await asyncio.sleep(.01)
        pid = int((self.root / 'pid').read_text())
        task.cancel(); await asyncio.gather(task, return_exceptions=True)
        with self.assertRaises(ProcessLookupError): os.kill(pid, 0)
        with self.assertRaises(TimeoutError): await backend.run_command([str(slow)], timeout=.05)
        pid = int((self.root / 'pid').read_text())
        with self.assertRaises(ProcessLookupError): os.kill(pid, 0)

    async def test_application_file_launch_and_failed_action_history(self):
        request = dict(request=1, entry=dict(kind='application', id='demo'), command=['fake-app', 'literal $(echo hi)'], directory=str(self.root))
        await self.worker.activate(request)
        self.assertEqual(self.events[-1]['error'], '')
        action = json.loads((self.root / 'actions.jsonl').read_text().splitlines()[0])
        self.assertEqual(action['argv'], ['literal $(echo hi)'])
        self.assertEqual(action['cwd'], str(self.root))
        request.update(request=2, terminal=True)
        await self.worker.activate(request)
        self.assertEqual(json.loads((self.root / 'actions.jsonl').read_text().splitlines()[-1])['tool'], 'kitty')
        target = self.root / 'file with spaces.md'; target.touch()
        await self.worker.activate(dict(request=3, entry=dict(kind='file', id=str(target))))
        self.assertEqual(self.events[-1]['error'], '')
        self.assertEqual(self.worker.history.records[0]['id'], str(target))
        missing = self.root / 'missing'
        await self.worker.activate(dict(request=4, entry=dict(kind='file', id=str(missing))))
        self.assertTrue(self.events[-1]['error'])
        self.assertNotIn(str(missing), [entry['id'] for entry in self.worker.history.records])
        failure = self.root / 'fail-open'; failure.touch()
        await self.worker.activate(dict(request=5, entry=dict(kind='file', id=str(failure))))
        self.assertTrue(self.events[-1]['error'])
        request.update(command=['missing-executable'], terminal=False)
        await self.worker.activate(request)
        self.assertTrue(self.events[-1]['error'])

    async def test_launched_application_survives_worker_event_loop(self):
        pidfile = self.root / 'app.pid'
        script = self.root / 'app.py'
        script.write_text('import os,signal\nfrom pathlib import Path\nPath(' + repr(str(pidfile)) + ').write_text(str(os.getpid()))\nsignal.pause()\n')
        launcher = self.root / 'launch.py'
        launcher.write_text('import sys,asyncio\nsys.path.insert(0,' + repr(str(ROOT / 'services')) + ')\nfrom launcher_backend import launch\nasyncio.run(launch(' + repr([sys.executable, str(script)]) + '))\n')
        await backend.run_command([sys.executable, str(launcher)])
        pid = int(pidfile.read_text())
        try:
            os.kill(pid, 0)
        finally:
            import signal
            os.kill(pid, signal.SIGTERM)

    async def test_cliphist_sensitive_limit_exact_text_and_binary_roundtrip(self):
        text = b'  literal <b>hjkl</b>\nsecond line\n'
        for state, data in [('sensitive', text), ('nil', text), ('data', b'x' * (backend.MAX_BYTES + 1))]:
            result = await backend.run_command([sys.executable, str(ROOT / 'services/launcher_backend.py'), '--store'], data=data,
                    env=dict(self.worker.env, CLIPBOARD_STATE=state))
            self.assertEqual(result, b'')
        self.assertFalse((self.root / 'clipboard.db').exists())
        for data in [text, b'\x89PNG\r\n\x1a\n' + bytes(range(256))]:
            result = await backend.run_command([sys.executable, str(ROOT / 'services/launcher_backend.py'), '--store'], data=data, env=self.worker.env)
            self.assertEqual(result, b'stored\n')
            await self.worker.refresh_clipboard()
            key = self.worker.clips[0]['id']
            await self.worker.activate(dict(request=7, entry=dict(kind='clipboard', id=key)))
            self.assertEqual(self.events[-1]['error'], '')
            self.assertEqual((self.root / 'copied').read_bytes(), data)
            self.assertFalse(self.worker.history.path.exists())
        await self.worker.activate(dict(request=8, entry=dict(kind='clipboard', id='1;echo hi')))
        self.assertTrue(self.events[-1]['error'])
        await backend.run_command(['cliphist','wipe'],env=self.worker.env)
        await self.worker.refresh_clipboard()
        self.assertFalse(self.worker.clips)
        self.assertFalse(self.worker.session_history)

    async def test_preview_decodes_multiline_text_and_image_without_copying(self):
        text = ('  <b>Dosłowny tekst</b>\n' + 'Zażółć gęślą jaźń.\n' * 100).encode()
        image = (ROOT / 'tests/fixtures/launcher-preview.png').read_bytes()
        self.worker.visible = True
        for revision, data in enumerate([text, image], 1):
            await backend.run_command(['cliphist', 'store'], data=data, env=self.worker.env)
            await self.worker.refresh_clipboard()
            key = self.worker.clips[0]['id']
            await self.worker.preview_clipboard(dict(revision=revision, key=key))
            result = self.events[-1]
            self.assertEqual((result['type'], result['revision'], result['key'], result['error']), ('preview', revision, key, ''))
            if data == text:
                self.assertEqual(result['text'], data.decode())
                self.assertEqual(result['image'], '')
                self.assertGreater(len(result['text']), 160)
            else:
                self.assertEqual(result['text'], '')
                self.assertTrue(result['image'].startswith('data:image/png;base64,'))
                self.assertEqual(base64.b64decode(result['image'].split(',', 1)[1]), data)
        self.assertIsNone(self.worker.copy_owner)
        self.assertFalse((self.root / 'copied').exists())
        self.assertFalse(self.worker.history.path.exists())
        self.assertFalse(self.worker.session_history)

    async def test_preview_limits_invalid_missing_and_hidden_entries(self):
        self.worker.visible = True
        data = b'x' * (backend.MAX_PREVIEW_CHARS + 512)
        await backend.run_command(['cliphist', 'store'], data=data, env=self.worker.env)
        await self.worker.refresh_clipboard()
        key = self.worker.clips[0]['id']
        await self.worker.preview_clipboard(dict(revision=1, key=key))
        self.assertEqual(len(self.events[-1]['text']), backend.MAX_PREVIEW_CHARS)
        for key in ['1;touch INJECTED', '../clipboard.db', '999999']:
            await self.worker.preview_clipboard(dict(revision=2, key=key))
            self.assertTrue(self.events[-1]['error'])
            self.assertEqual(self.events[-1]['text'], '')
            self.assertEqual(self.events[-1]['image'], '')
        self.assertFalse((self.root / 'INJECTED').exists())
        key = self.worker.clips[0]['id']
        await backend.run_command(['cliphist', 'wipe'], env=self.worker.env)
        await self.worker.preview_clipboard(dict(revision=3, key=key))
        self.assertTrue(self.events[-1]['error'])
        self.worker.visible = False
        count = len(self.events)
        await self.worker.preview_clipboard(dict(revision=4, key=key))
        self.assertEqual(len(self.events), count)

    async def test_cancel_preview_reaps_decoder_and_emits_no_stale_content(self):
        decoder = self.bin / 'cliphist'
        decoder.write_text('#!/usr/bin/python3\nimport os,signal\nfrom pathlib import Path\nPath(os.environ["PUTKIN_LAUNCHER_FIXTURE"]+"/preview.pid").write_text(str(os.getpid()))\nsignal.pause()\n')
        decoder.chmod(0o700)
        self.worker.clips = [dict(id='1', preview='fixture', binary=False)]
        self.worker.visible = True
        self.worker.preview_task = asyncio.create_task(self.worker.preview_clipboard(dict(revision=1, key='1')))
        for _ in range(100):
            if (self.root / 'preview.pid').exists(): break
            await asyncio.sleep(.01)
        pid = int((self.root / 'preview.pid').read_text())
        await self.worker.cancel_preview()
        self.assertIsNone(self.worker.preview_task)
        self.assertEqual(self.events, [])
        with self.assertRaises(ProcessLookupError): os.kill(pid, 0)


if __name__ == '__main__':
    unittest.main()
