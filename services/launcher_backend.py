#!/usr/bin/env python3
"""Launcher I/O: bounded searches, private MRU, session-only clipboard.

One event-driven worker, no polling. Only typed JSON requests on stdin;
never interprets search text or filenames as shell commands.
"""
import asyncio
import base64
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile

MAX_ITEMS = 100
MAX_BYTES = 2 * 1024 * 1024
MAX_PREVIEW_CHARS = 32768


def valid_record(record):
    return (isinstance(record, dict) and record.get('kind') in ('application', 'file')
            and isinstance(record.get('id'), str) and 0 < len(record['id']) <= 8192
            and '\0' not in record['id']
            and (record['kind'] != 'file' or record['id'].startswith('/')))


class History:
    def __init__(self, path):
        self.path = Path(path)
        self.records = []
        self.error = ''
        try:
            if self.path.exists():
                if self.path.stat().st_size > 1024 * 1024:
                    raise ValueError('size')
                data = json.loads(self.path.read_text())
                if data.get('schemaVersion') != 1 or not isinstance(data.get('records'), list):
                    raise ValueError('schema')
                self.records = self.unique(data['records'])
        except (OSError, ValueError, AttributeError):
            # Do not silently replace unreadable/foreign history.
            self.error = 'Nie można odczytać historii launchera.'

    @staticmethod
    def unique(records):
        seen, result = set(), []
        for record in records:
            if not valid_record(record):
                continue
            key = (record['kind'], record['id'])
            if key not in seen:
                seen.add(key)
                result.append(dict(kind=key[0], id=key[1]))
        return result[:MAX_ITEMS]

    def record(self, entry):
        self.records = self.unique([entry] + self.records)
        if self.error:
            return self.error
        temp = None
        try:
            self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(mode='w', dir=self.path.parent, delete=False) as stream:
                temp = Path(stream.name)
                json.dump(dict(schemaVersion=1, records=self.records), stream)
                stream.flush()
                os.fsync(stream.fileno())
            temp.replace(self.path)
            return ''
        except OSError:
            return 'Nie można zapisać historii launchera.'
        finally:
            if temp:
                temp.unlink(missing_ok=True)


async def run_command(argv, *, data=None, env=None, timeout=3):
    child = await asyncio.create_subprocess_exec(*argv, stdin=asyncio.subprocess.PIPE if data is not None else subprocess.DEVNULL,
        stdout=asyncio.subprocess.PIPE, stderr=subprocess.DEVNULL, env=env)
    try:
        output, _ = await asyncio.wait_for(child.communicate(data), timeout)
        if child.returncode:
            raise RuntimeError('command failed')
        return output
    finally:
        if child.returncode is None:
            child.kill()
        await child.wait()


async def launch(argv, directory=None):
    # asyncio transports terminate surviving children when their loop closes.
    # Popen intentionally transfers application lifetime outside this worker.
    child = subprocess.Popen(argv, cwd=directory or None,
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    await asyncio.sleep(0.15)
    if child.poll():
        raise RuntimeError('launch failed')


def store_clipboard():
    if os.environ.get('CLIPBOARD_STATE', 'data') in ('sensitive', 'nil', 'clear'):
        return
    data = sys.stdin.buffer.read(MAX_BYTES + 1)
    if not data or len(data) > MAX_BYTES:
        return
    try:
        subprocess.run(['cliphist', 'store'], input=data, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=3, check=True)
        print('stored', flush=True)
    except (OSError, subprocess.SubprocessError):
        print('failed', flush=True)


class Worker:
    def __init__(self, root, state, runtime):
        self.root = str(Path(root).resolve())
        self.history = History(state)
        self.runtime = runtime
        self.env = dict(os.environ, CLIPHIST_DB_PATH=str(Path(runtime) / 'clipboard.db'),
                        CLIPHIST_MAX_ITEMS=str(MAX_ITEMS), CLIPHIST_PREVIEW_WIDTH='160')
        self.visible = False
        self.clips = []
        self.clip_error = ''
        self.watchers = []
        self.watch_tasks = []
        self.search_task = None
        self.preview_task = None
        self.clip_lock = asyncio.Lock()
        self.session_history = list(self.history.records)
        self.closing = False
        self.copy_owner = None

    @staticmethod
    def emit(**event):
        print(json.dumps(event, ensure_ascii=True), flush=True)

    async def watch(self, mime):
        child = None
        try:
            child = await asyncio.create_subprocess_exec('wl-paste', '--type', mime, '--watch',
                sys.executable, str(Path(__file__).resolve()), '--store', env=self.env,
                stdout=asyncio.subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
            self.watchers.append(child)
            while line := await child.stdout.readline():
                if line.strip() == b'failed':
                    self.clip_error = 'Nie można zapisać wpisu schowka.'
                elif line.strip() == b'stored':
                    self.clip_error = ''
                if self.visible:
                    await self.refresh_clipboard()
            await child.wait()
            if not self.closing:
                self.clip_error = 'Historia schowka jest niedostępna (wl-paste).'
                self.emit(type='clipboard', entries=self.clips, error=self.clip_error)
        except OSError:
            self.clip_error = 'Schowek wymaga wl-clipboard i cliphist.'
            self.emit(type='clipboard', entries=[], error=self.clip_error)
        finally:
            if child and child.returncode is None:
                os.killpg(child.pid, signal.SIGKILL)
                await child.wait()

    async def refresh_clipboard(self):
        async with self.clip_lock:
            try:
                if not Path(self.env['CLIPHIST_DB_PATH']).exists():
                    self.clips = []
                else:
                    output = await run_command(['cliphist', 'list'], env=self.env)
                    entries = []
                    for line in output.decode('utf-8', 'replace').splitlines():
                        key, separator, preview = line.partition('\t')
                        if separator and key.isdecimal():
                            entries.append(dict(id=key, preview=preview, binary=preview.startswith('[[ binary data')))
                    self.clips = entries[:MAX_ITEMS]
                ids = {entry['id'] for entry in self.clips}
                self.session_history = [entry for entry in self.session_history
                    if entry['kind'] != 'clipboard' or entry['id'] in ids]
            except (OSError, RuntimeError, TimeoutError):
                self.clip_error = 'Nie można odczytać historii schowka.'
            self.emit(type='clipboard', entries=self.clips, error=self.clip_error)
            self.emit(type='history', entries=self.session_history, error=self.history.error)

    async def search(self, request):
        revision, query = request['revision'], request.get('query', '')
        if not query:
            self.emit(type='files', revision=revision, entries=[], error='')
            return
        try:
            output = await run_command(['fd', '--type', 'file', '--absolute-path', '--fixed-strings',
                '--ignore-case', '--no-ignore', '--one-file-system', '--max-results', str(MAX_ITEMS),
                '--print0', '--', query, self.root])
            self.emit(type='files', revision=revision, entries=[os.fsdecode(path) for path in output.split(b'\0') if path], error='')
        except (OSError, RuntimeError, TimeoutError):
            self.emit(type='files', revision=revision, entries=[], error='Nie można wyszukać plików (fd).')

    async def decode_clipboard(self, key):
        if not isinstance(key, str) or not key.isdecimal() or not any(entry['id'] == key for entry in self.clips):
            raise ValueError('clipboard id')
        data = await run_command(['cliphist', 'decode'], data=(key + '\t').encode(), env=self.env)
        if len(data) > MAX_BYTES:
            raise ValueError('clipboard size')
        return data

    async def preview_clipboard(self, request):
        key = request.get('key', '')
        if not self.visible or not key:
            return
        text, image, error = '', '', ''
        try:
            data = await self.decode_clipboard(key)
            entry = next(entry for entry in self.clips if entry['id'] == key)
            mime = (await run_command(['file', '--brief', '--mime-type', '-'], data=data)).decode().strip()
            if mime.startswith('image/'):
                image = 'data:' + mime + ';base64,' + base64.b64encode(data).decode('ascii')
            elif entry['binary']:
                text = entry['preview']
            else:
                text = data.decode('utf-8', 'replace')[:MAX_PREVIEW_CHARS]
        except (OSError, RuntimeError, ValueError, TimeoutError, StopIteration):
            error = 'Nie można odczytać podglądu schowka.'
        self.emit(type='preview', revision=request['revision'], key=key, text=text, image=image, error=error)

    async def cancel_preview(self):
        if self.preview_task:
            self.preview_task.cancel()
            await asyncio.gather(self.preview_task, return_exceptions=True)
            self.preview_task = None

    async def copy_clipboard(self, key):
        data = await self.decode_clipboard(key)
        mime = (await run_command(['file', '--brief', '--mime-type', '-'], data=data)).decode().strip()
        # Foreground ownership is intentional: the worker cleans it up on exit.
        # wl-copy closes stdin after reading, then remains alive to serve Wayland.
        child = await asyncio.create_subprocess_exec('wl-copy', '--foreground', '--type', mime,
            stdin=asyncio.subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            child.stdin.write(data)
            await asyncio.wait_for(child.stdin.drain(), 3)
            child.stdin.close()
            await child.stdin.wait_closed()
            try:
                await asyncio.wait_for(asyncio.shield(child.wait()), 0.15)
                if child.returncode:
                    raise RuntimeError('copy failed')
            except TimeoutError:
                pass
        except BaseException:
            if child.returncode is None:
                child.kill()
            await child.wait()
            raise
        if self.copy_owner and self.copy_owner.returncode is None:
            self.copy_owner.terminate()
            await self.copy_owner.wait()
        self.copy_owner = child

    async def activate(self, request):
        entry = request['entry']
        kind, key = entry.get('kind'), entry.get('id')
        try:
            if kind == 'clipboard':
                await self.copy_clipboard(key)
            elif kind == 'file':
                if not valid_record(entry) or not Path(key).is_file():
                    raise ValueError('missing file')
                await launch(['xdg-open', key])
            elif kind == 'application':
                # Native DesktopEntry supplies argv and workingDirectory.
                argv = request.get('command')
                if not valid_record(entry) or not isinstance(argv, list) or not argv or not all(isinstance(arg, str) for arg in argv):
                    raise ValueError('application command')
                if request.get('terminal'):
                    argv = ['kitty', '-e'] + argv
                await launch(argv, request.get('directory'))
            else:
                raise ValueError('unsupported action')
            record = dict(kind=kind, id=key)
            self.session_history = ([record] + [old for old in self.session_history if old != record])[:MAX_ITEMS]
            warning = self.history.record(record) if kind != 'clipboard' else ''
            self.emit(type='history', entries=self.session_history, error=warning or self.history.error)
            self.emit(type='activated', request=request['request'], error='')
        except (OSError, RuntimeError, ValueError, TimeoutError):
            self.emit(type='activated', request=request['request'], error='Nie można otworzyć wybranej pozycji.' if kind != 'clipboard' else 'Nie można przywrócić wpisu schowka.')

    async def serve(self):
        loop = asyncio.get_running_loop()
        reader = asyncio.StreamReader()
        transport, _ = await loop.connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
        if all(shutil.which(name) for name in ('wl-paste', 'wl-copy', 'cliphist', 'file')):
            self.watch_tasks = [asyncio.create_task(self.watch(mime)) for mime in ('text', 'image')]
        else:
            self.clip_error = 'Schowek wymaga wl-clipboard, cliphist i file.'
        self.emit(type='ready', entries=self.session_history, error=self.history.error, clipboardError=self.clip_error)
        try:
            while line := await reader.readline():
                request = json.loads(line)
                operation = request.get('op')
                if operation == 'visible':
                    self.visible = bool(request.get('value'))
                    if self.visible:
                        await self.refresh_clipboard()
                    else:
                        await self.cancel_preview()
                elif operation == 'preview':
                    await self.cancel_preview()
                    if self.visible and request.get('key'):
                        self.preview_task = asyncio.create_task(self.preview_clipboard(request))
                elif operation == 'search':
                    if self.search_task:
                        self.search_task.cancel()
                        await asyncio.gather(self.search_task, return_exceptions=True)
                    self.search_task = asyncio.create_task(self.search(request))
                elif operation == 'activate':
                    await self.activate(request)
        finally:
            self.closing = True
            transport.close()
            tasks = self.watch_tasks + [task for task in (self.search_task, self.preview_task) if task]
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
            if self.copy_owner and self.copy_owner.returncode is None:
                self.copy_owner.terminate()
                await self.copy_owner.wait()


async def main():
    os.umask(0o077)
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'putkin/launcher.json'
    with tempfile.TemporaryDirectory(prefix='putkin-clipboard-', dir=runtime) as directory:
        worker = Worker(Path.home(), state, directory)
        task = asyncio.current_task()
        for sig in (signal.SIGTERM, signal.SIGINT):
            asyncio.get_running_loop().add_signal_handler(sig, task.cancel)
        try:
            await worker.serve()
        except asyncio.CancelledError:
            pass


if __name__ == '__main__':
    if sys.argv[1:] == ['--store']:
        store_clipboard()
    else:
        asyncio.run(main())
