"""Per-call PulseAudio streams. No recording, global mute or persistent loopback."""
import asyncio
import os
import re

from signal_process import child_command
from signal_transport import Failure, stop_child


class CallAudio:
    def __init__(self):
        self.pairs = {}
        self.devices = None
        self.lock = asyncio.Lock()

    async def default(self, kind):
        child = await asyncio.create_subprocess_exec(
            *child_command(["pactl", "get-default-" + kind]),
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        try:
            output, _ = await asyncio.wait_for(child.communicate(), 3)
            name = output.decode().strip()
            if child.returncode or not name or len(name) > 512 or name.startswith(("signal_", "sink_for_signal_")):
                raise Failure("call_audio_unavailable")
            return name
        except (OSError, UnicodeError, asyncio.TimeoutError):
            raise Failure("call_audio_unavailable") from None
        finally:
            if child.returncode is None:
                child.kill()
            await child.wait()

    async def pair(self, name, source, sink):
        read_fd, write_fd = os.pipe()
        children = []
        args = ["pacat", "--raw", "--rate=48000", "--channels=1", "--format=s16le",
                "--latency-msec=40", "--client-name=Putkin Signal", "--stream-name=" + name]
        try:
            for mode, device, stdin, stdout in (
                    ("--record", source, asyncio.subprocess.DEVNULL, write_fd),
                    ("--playback", sink, read_fd, asyncio.subprocess.DEVNULL)):
                task = asyncio.create_task(asyncio.create_subprocess_exec(
                    *child_command([*args, mode, "--device=" + device]), stdin=stdin, stdout=stdout,
                    stderr=asyncio.subprocess.DEVNULL))
                try:
                    children.append(await asyncio.shield(task))
                except asyncio.CancelledError:
                    children.append(await task)
                    raise
            self.pairs[name] = children
        except BaseException:
            await self.stop_pair(children)
            raise
        finally:
            os.close(read_fd)
            os.close(write_fd)

    async def start(self, input_name, output_name, muted=False):
        async with self.lock:
            if self.devices:
                return
            if not re.fullmatch(r"signal_input_[0-9]{1,20}", input_name or "") or not re.fullmatch(r"signal_output_[0-9]{1,20}", output_name or ""):
                raise Failure("call_audio_unavailable")
            try:
                source, sink = await self.default("source"), await self.default("sink")
                self.devices = (source, "sink_for_" + input_name, output_name + ".monitor", sink)
                await self.pair("receive", self.devices[2], sink)
                if not muted:
                    await self.pair("microphone", source, self.devices[1])
            except asyncio.CancelledError:
                await self.close_unlocked()
                raise
            except (OSError, Failure):
                await self.close_unlocked()
                raise Failure("call_audio_unavailable") from None

    async def mute(self, muted):
        async with self.lock:
            await self.stop_pair(self.pairs.pop("microphone", []))
            if not muted and self.devices:
                await self.pair("microphone", *self.devices[:2])

    async def watch(self):
        # Wait on actual process exits; no idle polling or host-level process search.
        children = [child for pair in self.pairs.values() for child in pair]
        if not children:
            return
        tasks = [asyncio.create_task(child.wait()) for child in children]
        try:
            await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        finally:
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)

    async def stop_pair(self, children):
        for child in children:
            if child.returncode is None:
                try:
                    child.terminate()
                except ProcessLookupError:
                    pass
        await asyncio.gather(*(stop_child(child) for child in children))

    async def close_unlocked(self):
        children = [child for pair in self.pairs.values() for child in pair]
        self.pairs = {}
        self.devices = None
        await self.stop_pair(children)

    async def close(self):
        async with self.lock:
            await self.close_unlocked()
