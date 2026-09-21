"""S01 behavior tests. Only explicit synthetic CLI and private XDG directories."""
import asyncio
import ctypes
import fcntl
import json
import os
from pathlib import Path
import select
import shlex
import signal
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services"))
from signal_transport import Failure, MAX_FRAME, RpcTransport, frame, spawn, version


def environment(base):
    env = {"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"}
    for kind in ("CONFIG", "DATA", "CACHE", "RUNTIME"):
        path = base / kind.lower()
        path.mkdir(mode=0o700)
        env[f"XDG_{kind}_{'DIR' if kind == 'RUNTIME' else 'HOME'}"] = str(path)
    return env


def gone(pid, seconds=6):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            os.waitpid(pid, os.WNOHANG)  # Reap only a known test descendant.
        except ChildProcessError:
            pass
        if not Path(f"/proc/{pid}").exists():
            return True
        time.sleep(.02)
    return False


class Client:
    def __init__(self, env, scenario=None, command=None):
        argv = [sys.executable, "-B", str(ROOT / "services/signal_backend.py")]
        if scenario:
            argv += ["--test-scenario", str(scenario)]
        self.process = subprocess.Popen(command or argv, env=env, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.buffer = b""
        self.frames = []
        self.generation = ""

    def read(self, predicate, seconds=8):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            for index, value in enumerate(self.frames):
                if predicate(value):
                    return self.frames.pop(index)
            if not select.select([self.process.stdout], [], [], max(0, deadline - time.monotonic()))[0]:
                break
            raw = os.read(self.process.stdout.fileno(), 65536)
            if not raw:
                raise AssertionError("bridge EOF before expected result: " + self.process.stderr.read().decode())
            self.buffer += raw
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                value = json.loads(line)
                if value["type"] == "hello":
                    self.generation = value["generation"]
                self.frames.append(value)
        raise AssertionError("No expected bridge result")

    def state(self, state, seconds=8):
        return self.read(lambda v: v.get("data", {}).get("serviceState") == state, seconds)

    def send(self, request_id, method, params=None, **overrides):
        value = {"v": 1, "type": "request", "id": request_id, "generation": self.generation,
                 "method": method, "params": params or {}, **overrides}
        self.process.stdin.write((json.dumps(value) + "\n").encode())
        self.process.stdin.flush()

    def reply(self, request_id, seconds=8):
        return self.read(lambda v: v.get("type") == "response" and v.get("id") == request_id, seconds)

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=7)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=2)
        for stream in (self.process.stdin, self.process.stdout, self.process.stderr):
            stream.close()


class TransportTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="pk-signal-rpc-")
        self.base = Path(self.temporary.name)
        self.lock = os.open(self.base / "owner.lock", os.O_CREAT | os.O_RDWR, 0o600)
        fcntl.flock(self.lock, fcntl.LOCK_EX)
        self.transports = []

    async def asyncTearDown(self):
        for transport in self.transports:
            await transport.close()
        os.close(self.lock)
        self.temporary.cleanup()

    async def peer(self, **config):
        fixture = self.base / f"fixture-{len(self.transports)}.json"
        fixture.write_text(json.dumps({"format": 1, "synthetic": True, **config}))
        command = [sys.executable, "-B", str(ROOT / "tests/signal_cli_fake.py"), "--lifecycle-scenario", str(fixture)]
        await version(command, self.lock)
        child = await spawn(command, self.lock)
        events = []
        transport = RpcTransport(child, events.append)
        self.transports.append(transport)
        return transport, events

    async def test_partial_utf8_coalesced_frames_and_event_before_reply(self):
        transport, events = await self.peer(chunkBytes=1, chunkDelay=.0001)
        self.assertEqual(await transport.request("subscribeReceive"), 0)
        self.assertEqual(events[0]["params"]["result"]["envelope"]["dataMessage"]["message"], "Zażółć 🐈\nwiersz")
        # Deterministic framing including a split UTF-8 sequence and coalescing.
        reader = asyncio.StreamReader(limit=MAX_FRAME)
        task = asyncio.create_task(frame(reader))
        raw = '{"s":"🐈"}\n{"s":2}\n'.encode()
        for byte in raw:
            reader.feed_data(bytes([byte]))
            await asyncio.sleep(0)
        self.assertEqual(await task, {"s": "🐈"})
        self.assertEqual(await frame(reader), {"s": 2})

    async def test_out_of_order_timeout_late_reply_and_cancellation(self):
        transport, _ = await self.peer()
        slow = asyncio.create_task(transport.request("echo", {"delay": .15, "value": "slow"}))
        fast = asyncio.create_task(transport.request("echo", {"value": "fast"}))
        self.assertEqual((await fast)["value"], "fast")
        self.assertFalse(slow.done())
        self.assertEqual((await slow)["value"], "slow")
        with self.assertRaisesRegex(Failure, "timeout"):
            await transport.request("echo", {"delay": .1}, timeout=.02)
        mutation = asyncio.create_task(transport.request("mutate", {"delay": .1}, mutating=True))
        await asyncio.sleep(.02)
        mutation.cancel()
        with self.assertRaisesRegex(Failure, "result_unknown"):
            await mutation
        with self.assertRaisesRegex(Failure, "busy"):
            await transport.request("mutate", mutating=True)
        read = asyncio.create_task(transport.request("echo", {"delay": .1}))
        await asyncio.sleep(.01)
        read.cancel()
        with self.assertRaisesRegex(Failure, "cancelled"):
            await read
        await asyncio.sleep(.15)
        self.assertEqual(await transport.request("echo", {"value": "new"}), {"value": "new"})
        self.assertEqual(await transport.request("mutate", {"value": "settled"}, mutating=True), {"value": "settled"})

    async def test_limits_and_stop_inflight_never_succeed(self):
        transport, _ = await self.peer()
        reads = [asyncio.create_task(transport.request("echo", {"delay": 10})) for _ in range(8)]
        mutation = asyncio.create_task(transport.request("mutate", {"delay": 10}, mutating=True))
        await asyncio.sleep(.04)
        for mutating in (True, False):
            with self.assertRaisesRegex(Failure, "busy"):
                await transport.request("echo", mutating=mutating)
        await transport.close()
        results = await asyncio.gather(*reads, mutation, return_exceptions=True)
        self.assertTrue(all(isinstance(result, Failure) for result in results))
        self.assertEqual(results[-1].code, "result_unknown")

    async def test_corrupt_large_truncated_utf8_and_version(self):
        for fault, code in (("malformed", "invalid_frame"), ("oversized", "frame_too_large"),
                            ("truncated", "incomplete_frame"), ("invalidUtf8", "invalid_frame")):
            with self.subTest(fault=fault):
                transport, _ = await self.peer()
                with self.assertRaisesRegex(Failure, code):
                    await transport.request("echo", {"fault": fault})
        with self.assertRaisesRegex(Failure, "unsupported_version"):
            await self.peer(version="9.9.9")


class LifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Tests reap the known descendants of deliberately killed owners.
        if ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) != 0:  # PR_SET_CHILD_SUBREAPER
            raise RuntimeError("subreaper unavailable")

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="pk-signal-owner-")
        self.base = Path(self.temporary.name)
        self.env = environment(self.base)
        self.fixture = self.base / "fixture.json"
        self.record = self.base / "processes.jsonl"
        self.configure()
        self.clients = []

    def configure(self, **values):
        self.fixture.write_text(json.dumps({"format": 1, "synthetic": True, "record": str(self.record), **values}))

    def start(self, *, synthetic=True, command=None):
        client = Client(self.env, self.fixture if synthetic else None, command)
        self.clients.append(client)
        return client

    def records(self, kind=None):
        values = [json.loads(line) for line in self.record.read_text().splitlines()] if self.record.exists() else []
        return [v for v in values if kind is None or v["kind"] == kind]

    def tearDown(self):
        for client in reversed(self.clients):
            client.close()
        for record in self.records("start"):
            self.assertTrue(gone(record["pid"]), "orphan synthetic CLI")
        self.temporary.cleanup()

    def config(self, value):
        directory = Path(self.env["XDG_CONFIG_HOME"]) / "putkin"
        directory.mkdir(mode=0o700, exist_ok=True)
        path = directory / "signal.json"
        path.write_text(json.dumps(value))
        path.chmod(0o600)

    def test_unconfigured_idle_disabled_and_missing_binary(self):
        client = self.start(synthetic=False)
        client.state("idle")
        client.send("status", "service.status")
        capabilities = client.reply("status")["result"]["capabilities"]
        self.assertEqual(capabilities[:3], ["service.status", "service.retry", "request.cancel"])
        self.assertIn("account.link.start", capabilities)
        self.assertNotIn("message.send", capabilities)
        self.assertFalse(self.record.exists())
        client.close()
        self.config({"v": 1, "enabled": False})
        client = self.start(synthetic=False)
        client.state("disabled")
        client.close()
        self.config({"v": 1, "enabled": True, "executable": "/missing/signal-cli"})
        client = self.start(synthetic=False)
        self.assertEqual(client.state("failed")["data"]["errorCode"], "cli_unavailable")
        time.sleep(.15)
        self.assertIsNone(client.process.poll())
        self.assertFalse(self.record.exists())

    def test_production_requires_media_policy_and_durable_store_before_subscribe(self):
        # Explicit executable injection exercises the production branch; its
        # linked identity is synthetic, with no --test-scenario bridge switch.
        wrapper = self.base / "signal-cli"
        argv = [sys.executable, "-B", str(ROOT / "tests/signal_cli_fake.py"),
                "--lifecycle-scenario", str(self.fixture)]
        wrapper.write_text("#!/bin/sh\nexec " + shlex.join(argv) + ' "$@"\n')
        wrapper.chmod(0o700)
        self.config({"v": 1, "enabled": True, "executable": str(wrapper)})
        client = self.start(synthetic=False)
        state = client.state("failed")
        self.assertEqual(state["data"]["errorCode"], "media_policy_required")
        self.assertEqual(state["data"]["schemaVersion"], 7)
        self.assertEqual(len(self.records("subscribe")), 0)
        client.send("bypass", "test.echo")
        self.assertEqual(client.reply("bypass")["error"]["code"], "unsupported_method")
        path = Path(self.env["XDG_DATA_HOME"]) / "putkin/signal/history.sqlite3"
        db = sqlite3.connect(path)
        self.assertEqual(db.execute("SELECT COUNT(*) FROM messages").fetchone()[0], 0)
        db.close()
        client.close()
        path.write_bytes(b"broken database")
        client = self.start(synthetic=False)
        self.assertEqual(client.state("failed")["data"]["errorCode"], "storage_error")
        self.assertEqual(len(self.records("subscribe")), 0)

    def test_backoff_stops_after_five_retries_and_explicit_retry_recovers(self):
        self.configure(crashAfterSubscribe=True)
        started = time.monotonic()
        client = self.start()
        state = client.state("failed", seconds=45)
        self.assertEqual(state["data"]["retryCount"], 5)
        self.assertEqual(len(self.records("start")), 6)
        self.assertGreaterEqual(time.monotonic() - started, 31)
        time.sleep(.15)
        self.assertEqual(len(self.records("start")), 6)
        self.configure()
        client.frames.clear()
        client.send("retry", "service.retry")
        client.reply("retry")
        self.assertEqual(client.state("ready")["data"]["retryCount"], 0)

    def test_ipc_burst_limit_and_invalid_version(self):
        client = self.start()
        client.state("ready")
        values = [{"v": 1, "type": "request", "generation": client.generation, "id": str(i),
                   "method": "test.echo", "params": {"delay": .1}} for i in range(40)]
        client.process.stdin.write(b"".join((json.dumps(v) + "\n").encode() for v in values))
        client.process.stdin.flush()
        results = [client.reply(str(i)) for i in range(40)]
        self.assertTrue(any(v.get("error", {}).get("code") == "busy" for v in results))
        self.assertTrue(all("result" in v or v["error"]["code"] == "busy" for v in results))
        client.send("version", "service.status", v=2)
        self.assertEqual(client.reply("version")["error"]["code"], "unsupported_version")

    def test_two_starts_stale_lock_inode_and_reload(self):
        first, second = self.start(), self.start()
        # Either contender can win. Both must report a bounded state.
        one = first.read(lambda v: v.get("data", {}).get("serviceState") in ("ready", "reconnecting"))
        winner, loser = (first, second) if one["data"]["serviceState"] == "ready" else (second, first)
        if winner is second:
            winner.state("ready")
        self.assertEqual(loser.state("failed")["data"]["errorCode"], "busy")
        self.assertEqual(len(self.records("start")), 1)
        self.assertEqual(len(self.records("subscribe")), 1)
        lock = Path(self.env["XDG_DATA_HOME"]) / "putkin/signal/owner.lock"
        inode = lock.stat().st_ino
        lock.write_text(str(os.getpid()))  # Stale/reused PID text has no authority.
        winner.close()
        loser.send("retry", "service.retry")
        self.assertTrue(loser.reply("retry")["result"]["accepted"])
        loser.state("ready")
        self.assertEqual(lock.stat().st_ino, inode)
        self.assertEqual(len(self.records("subscribe")), 2)

    def test_reconnect_generation_error_redaction_and_explicit_cancel(self):
        client = self.start()
        client.state("ready")
        old_generation = client.generation
        client.send("cancel-me", "test.mutate", {"delay": .15})
        time.sleep(.05)
        client.send("cancel", "request.cancel", {"id": "cancel-me"})
        self.assertTrue(client.reply("cancel")["result"]["accepted"])
        self.assertEqual(client.reply("cancel-me")["error"]["code"], "result_unknown")
        time.sleep(.2)  # Late response releases the mutation slot, not its unknown result.
        client.send("crash", "test.mutate", {"fault": "crash"})
        self.assertEqual(client.reply("crash")["error"]["code"], "result_unknown")
        client.state("reconnecting")
        client.state("ready")
        self.assertNotEqual(client.generation, old_generation)
        client.send("stale", "test.echo", generation=old_generation)
        self.assertEqual(client.reply("stale")["error"]["code"], "stale_generation")
        client.send("unknown", "message.future")
        self.assertEqual(client.reply("unknown")["error"]["code"], "unsupported_method")
        client.process.stdin.close()
        client.process.wait(timeout=6)
        self.assertEqual(client.process.stderr.read(), b"")

    def test_eof_term_kill_helper_and_owned_shell(self):
        for mode in ("eof", "term", "kill", "owner-term", "owner-kill"):
            with self.subTest(mode=mode):
                marker = self.base / "bridge.pid"
                if mode.startswith("owner"):
                    argv = [sys.executable, "-B", str(ROOT / "services/signal_backend.py"), "--test-scenario", str(self.fixture)]
                    code = ("import pathlib, subprocess, time; "
                            f"p = subprocess.Popen({argv!r}, stdin=subprocess.PIPE); "
                            f"pathlib.Path({str(marker)!r}).write_text(str(p.pid)); time.sleep(60)")
                    client = self.start(command=[sys.executable, "-c", code])
                else:
                    client = self.start()
                client.state("ready")
                child_pid = self.records("start")[-1]["pid"]
                helper_pid = int(marker.read_text()) if mode.startswith("owner") else client.process.pid
                if mode == "eof":
                    client.process.stdin.close()
                else:
                    os.kill(client.process.pid, signal.SIGKILL if "kill" in mode else signal.SIGTERM)
                client.process.wait(timeout=6)
                self.assertTrue(gone(helper_pid))
                self.assertTrue(gone(child_pid))

    def test_forced_cleanup_holds_lock_until_cli_dies(self):
        self.configure(ignoreEof=True, ignoreTerm=True)
        first = self.start()
        first.state("ready")
        first.process.stdin.close()
        time.sleep(.05)
        second = self.start()
        second.state("reconnecting")
        self.assertEqual(len(self.records("start")), 1)
        first.process.wait(timeout=6)
        self.assertEqual(first.process.returncode, 0)
        second.state("ready")

    def test_invalid_version_accounts_and_ipc_frames_are_finite(self):
        for config, expected in (({"version": "0.1"}, "unsupported_version"),
                                 ({"accounts": [{"number": "one"}, {"number": "two"}]}, "multiple_accounts"),
                                 ({"fault": "malformed"}, "invalid_frame")):
            with self.subTest(config=config):
                self.configure(**config)
                client = self.start()
                self.assertEqual(client.state("failed")["data"]["errorCode"], expected)
                client.close()
        self.configure(accounts=[])
        client = self.start()
        client.state("idle")
        starts = len(self.records("start"))
        time.sleep(.2)
        self.assertEqual(len(self.records("start")), starts)
        client.process.stdin.write(b"x" * (MAX_FRAME + 1))
        client.process.stdin.flush()
        self.assertEqual(client.state("failed")["data"]["errorCode"], "frame_too_large")
        client.process.wait(timeout=6)

    def test_private_paths_and_lock_symlinks_rejected(self):
        self.env["XDG_RUNTIME_DIR"] = "relative"
        client = self.start()
        self.assertEqual(client.state("failed")["data"]["errorCode"], "unsafe_path")
        client.close()
        self.env["XDG_RUNTIME_DIR"] = str(self.base / "runtime")
        store = Path(self.env["XDG_DATA_HOME"]) / "putkin/signal"
        store.mkdir(parents=True, mode=0o700)
        target = self.base / "unrelated"
        target.write_text("do not touch")
        (store / "owner.lock").symlink_to(target)
        client = self.start()
        self.assertEqual(client.state("failed")["data"]["errorCode"], "storage_error")
        self.assertEqual(target.read_text(), "do not touch")
        self.assertEqual(self.records(), [])


if __name__ == "__main__":
    unittest.main()
