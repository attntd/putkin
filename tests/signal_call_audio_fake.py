"""Explicit call-audio injection for the private bridge fixture; never opens audio."""
import asyncio
import json
from pathlib import Path
from signal_transport import Failure


class FakeCallAudio:
    def __init__(self, fixture):
        self.fixture = json.loads(Path(fixture).read_text())
        self.active = False

    def record(self, kind):
        if self.fixture.get("record"):
            with open(self.fixture["record"], "a") as stream:
                stream.write(json.dumps({"kind": kind, "synthetic": True}) + "\n")

    async def start(self, input_name, output_name, muted=False):
        if self.fixture.get("callAudioFail"):
            raise Failure("call_audio_unavailable")
        if not self.active:
            self.active = True
            self.record("call-audio-start-muted" if muted else "call-audio-start")

    async def watch(self):
        await asyncio.Future()

    async def mute(self, muted):
        if self.fixture.get("callMuteFail"):
            raise Failure("call_audio_unavailable")
        self.record("call-mute" if muted else "call-unmute")

    async def close(self):
        if self.active:
            self.record("call-audio-stop")
            self.active = False
