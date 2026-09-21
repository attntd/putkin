"""Bounded asynchronous NDJSON and JSON-RPC; no account or message policy."""
import asyncio
import json
import uuid

from signal_process import child_command

MAX_FRAME = 1024 * 1024


class Failure(Exception):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def encode(value):
    try:
        raw = (json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":")) + "\n").encode()
    except (ValueError, TypeError, UnicodeError, RecursionError):
        raise Failure("invalid_frame") from None
    if len(raw) > MAX_FRAME:
        raise Failure("frame_too_large")
    return raw


async def frame(reader):
    try:
        raw = await reader.readuntil(b"\n")
    except asyncio.IncompleteReadError as error:
        if not error.partial:
            raise Failure("transport_lost") from None
        raise Failure("incomplete_frame") from None
    except asyncio.LimitOverrunError:
        raise Failure("frame_too_large") from None
    if len(raw) > MAX_FRAME:
        raise Failure("frame_too_large")
    try:
        def invalid_constant(_):
            raise ValueError("non-finite JSON")
        value = json.loads(raw.decode("utf-8"), parse_constant=invalid_constant)
    except (ValueError, UnicodeError, RecursionError):
        raise Failure("invalid_frame") from None
    if not isinstance(value, dict):
        raise Failure("invalid_frame")
    return value


async def stop_child(process):
    """EOF, then TERM, then KILL, always reap before releasing owner.lock."""
    if process.stdin:
        process.stdin.close()
    for timeout, action in ((1, None), (2, process.terminate), (2, process.kill)):
        if process.returncode is not None:
            break
        if action:
            try:
                action()
            except ProcessLookupError:
                pass
        try:
            await asyncio.wait_for(process.wait(), timeout)
            break
        except asyncio.TimeoutError:
            continue
    # After SIGKILL a child cannot execute or reuse the account. Wait for reap.
    await process.wait()


async def spawn(command, lock_fd, env=None):
    task = asyncio.create_task(asyncio.create_subprocess_exec(
        *child_command(command), stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
        pass_fds=(lock_fd,), env=env, limit=MAX_FRAME))
    try:
        return await asyncio.shield(task)
    except asyncio.CancelledError:
        child = await task
        await stop_child(child)
        raise


async def version(command, lock_fd, env=None):
    child = await spawn([*command, "--version"], lock_fd, env)
    try:
        async with asyncio.timeout(10):
            raw = await child.stdout.readuntil(b"\n")
            if len(raw) > 256 or raw.strip() != b"signal-cli 0.14.8":
                raise Failure("unsupported_version")
            await child.wait()
            if child.returncode:
                raise Failure("cli_unavailable")
    except (asyncio.IncompleteReadError, asyncio.LimitOverrunError):
        raise Failure("cli_unavailable") from None
    except asyncio.TimeoutError:
        raise Failure("timeout") from None
    finally:
        await stop_child(child)


class RpcTransport:
    def __init__(self, child, on_event, generation=None):
        self.child = child
        self.on_event = on_event
        self.generation = generation or uuid.uuid4().hex
        self.counter = 0
        self.pending = {}
        self.results = {}
        self.abort_code = None
        self.uncertain_mutation = None
        self.closed = asyncio.get_running_loop().create_future()
        self.reader = asyncio.create_task(self.read())

    async def read(self):
        code = "transport_lost"
        try:
            while True:
                value = await frame(self.child.stdout)
                if value.get("jsonrpc") != "2.0":
                    raise Failure("invalid_frame")
                if "id" not in value:
                    if not isinstance(value.get("method"), str) or not isinstance(value.get("params"), dict):
                        raise Failure("invalid_frame")
                    self.on_event(value)
                    value = None  # Do not keep the last received body while idle.
                    continue
                if not isinstance(value["id"], str) or ("result" in value) == ("error" in value):
                    raise Failure("invalid_frame")
                if "error" in value and (not isinstance(value["error"], dict) or type(value["error"].get("code")) is not int):
                    raise Failure("invalid_frame")
                pending = self.pending.get(value["id"])
                if value["id"] == self.uncertain_mutation:
                    self.uncertain_mutation = None
                callback = self.results.pop(value["id"], None)
                if callback:
                    # Durable reconciliation also runs for late replies. The
                    # callback commits before this response can reach a caller.
                    callback(value.get("result"), value.get("error"))
                if pending and not pending[0].done():
                    if "error" in value:
                        # Upstream messages/data can contain private content.
                        pending[0].set_exception(Failure("rpc_error"))
                    else:
                        pending[0].set_result(value["result"])
                value = None
                # Old replies never resolve a different IPC request.
        except Failure as error:
            code = error.code
        except asyncio.CancelledError:
            pass
        finally:
            code = self.abort_code or code
            for future, mutating in self.pending.values():
                if not future.done():
                    future.set_exception(Failure("result_unknown" if mutating else code))
            if not self.closed.done():
                self.closed.set_result(code)
            self.results.clear()

    def abort(self, code):
        self.abort_code = code
        self.reader.cancel()

    async def request(self, method, params=None, *, mutating=False, timeout=None, on_result=None, drop_payload=False):
        if self.closed.done():
            raise Failure("transport_lost")
        if sum(not m for _, m in self.pending.values()) >= 8 and not mutating:
            raise Failure("busy")
        if mutating and (self.uncertain_mutation or any(m for _, m in self.pending.values())):
            raise Failure("busy")
        self.counter += 1
        request_id = f"{self.generation}:{self.counter}"
        raw = encode({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params or {}})
        future = asyncio.get_running_loop().create_future()
        self.pending[request_id] = (future, mutating)
        if on_result:
            self.results[request_id] = on_result
        submitted = False
        try:
            async with asyncio.timeout(timeout if timeout is not None else (60 if mutating else 10)):
                self.child.stdin.write(raw)
                submitted = True
                if drop_payload and params is not None:
                    params.clear()
                raw = None
                await self.child.stdin.drain()
                return await future
        except asyncio.TimeoutError:
            if mutating and submitted:
                self.uncertain_mutation = request_id
            raise Failure("result_unknown" if mutating and submitted else "timeout") from None
        except asyncio.CancelledError:
            if mutating and submitted:
                self.uncertain_mutation = request_id
            raise Failure("result_unknown" if mutating and submitted else "cancelled") from None
        except (BrokenPipeError, ConnectionError):
            raise Failure("result_unknown" if mutating and submitted else "transport_lost") from None
        finally:
            self.pending.pop(request_id, None)
            if not submitted:
                self.results.pop(request_id, None)
            if not future.done():
                future.cancel()

    async def close(self):
        self.reader.cancel()
        await asyncio.gather(self.reader, return_exceptions=True)
        await stop_child(self.child)
