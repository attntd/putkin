"""Ephemeral 1:1 calls on the owned signal-cli connection; no call replay/outbox."""
import asyncio
from collections import deque
import re
import time

from signal_call_audio import CallAudio
from signal_events import service_id
from signal_transport import Failure

CAPABILITIES = ["call.status", "call.start", "call.accept", "call.reject", "call.hangup", "call.mute", "call.dismiss"]
STATES = {"RINGING_INCOMING", "RINGING_OUTGOING", "CONNECTING", "CONNECTED", "RECONNECTING", "ENDED"}


def call_id(value):
    # Upstream emits signed Java longs. QML must never parse those as doubles.
    if type(value) is int and -(2 ** 63) <= value < 2 ** 63:
        return str(value)
    if isinstance(value, str) and re.fullmatch(r"-?(0|[1-9][0-9]{0,18})", value) and -(2 ** 63) <= int(value) < 2 ** 63:
        return str(int(value))
    raise Failure("invalid_call_event")


class Calls:
    def __init__(self, bridge, audio_factory=CallAudio):
        self.bridge = bridge
        self.audio_factory = audio_factory
        self.audio = audio_factory()
        self.current = None
        self.available = False
        self.subscription = None
        self.subscribing = False
        self.early = []
        self.ended = deque(maxlen=64)
        self.lock = asyncio.Lock()
        self.audio_task = None
        self.tasks = set()
        self.devices = (None, None)
        self.accepted = False

    def snapshot(self):
        return {"accountId": self.bridge.account_id, "available": self.available, "call": dict(self.current) if self.current else None}

    def publish(self):
        self.bridge.event("call.changed", self.snapshot())

    def task(self, coroutine):
        task = asyncio.create_task(coroutine)
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)
        return task

    async def subscribe(self, available):
        self.available = available
        if not available:
            return
        self.subscribing = True
        try:
            result = await self.rpc("subscribeCallEvents")
            if type(result) is not int:
                raise Failure("invalid_call_event")
            self.subscription = result
            for event in self.early:
                self.receive(event)
        except Failure:
            # Calling is optional; a call setup error must not stop text reception.
            self.available = False
        finally:
            self.subscribing = False
            self.early = []
        self.publish()

    async def rpc(self, method, params=None):
        b = self.bridge
        if not b.transport or not b.account_id:
            raise Failure("not_ready")
        # Calls use their own lock, independent of queued messages and receipts.
        # Any ambiguous call action tears down this transport instead of replaying.
        return await b.transport.request(method, {"account": b.store.account(b.account_id)["cli_address"], **(params or {})}, timeout=12)

    def receive(self, params):
        if self.subscription is None:
            if self.subscribing and len(self.early) < 16:
                self.early.append(params)
            return
        if params.get("subscription") != self.subscription:
            return
        try:
            value = params.get("result")
            if not isinstance(value, dict) or value.get("state") not in STATES or type(value.get("isOutgoing")) is not bool:
                raise Failure("invalid_call_event")
            cid = call_id(value.get("callId"))
            if cid in self.ended:
                return
            sid = service_id(value.get("uuid"))
            if not sid.startswith("aci:"):
                raise Failure("invalid_call_event")
            if self.current and self.current["state"] != "ENDED":
                if self.current["callId"] not in ("", cid) or self.current["peer"] != sid:
                    if value["state"] != "ENDED":
                        self.task(self.reject_extra(cid))
                    return
            else:
                if value["state"] == "ENDED":
                    self.ended.append(cid)
                    return
                # Only a locally initiated call or a ringing incoming offer may start a session.
                if value["isOutgoing"] or value["state"] != "RINGING_INCOMING":
                    self.task(self.reject_extra(cid))
                    return
                b = self.bridge
                with b.store.transaction():
                    conversation_id = b.store.route(b.account_id, {"peer": sid})
                conversation = b.store.conversation_item(b.account_id, conversation_id)
                if conversation["requestState"] == "blocked":
                    self.task(self.reject_extra(cid))
                    return
                self.new(conversation, False)
            if value["isOutgoing"] != self.current["isOutgoing"]:
                raise Failure("invalid_call_event")
            if value["state"] == "CONNECTED" and not self.accepted:
                self.task(self.reject_extra(cid, hangup=True))
                self.finish("invalid_call_event")
                return
            self.current.update(callId=cid, state=value["state"])
            self.devices = (value.get("inputDeviceName") or self.devices[0], value.get("outputDeviceName") or self.devices[1])
            if value["state"] == "ENDED":
                self.finish("ended")
            elif value["state"] == "CONNECTED":
                if not self.current["connectedAtMs"]:
                    self.current["connectedAtMs"] = int(time.time() * 1000)
                self.start_audio()
            self.publish()
        except (Failure, ValueError, TypeError):
            # Stop the owned CLI/tunnel if we cannot safely identify an event.
            if self.bridge.transport:
                self.bridge.transport.abort("transport_lost")
            self.finish("invalid_call_event")

    def new(self, conversation, outgoing):
        # Each call owns its streams. Late cleanup from a previous call must
        # never close the microphone of the next incoming call.
        self.audio = self.audio_factory()
        self.audio_task = None
        self.devices = (None, None)
        self.accepted = outgoing
        self.current = {"accountId": self.bridge.account_id, "conversationId": conversation["conversationId"],
                        "peer": conversation["target"], "title": conversation["title"], "callId": "",
                        "state": "STARTING" if outgoing else "RINGING_INCOMING", "isOutgoing": outgoing,
                        "muted": False, "connectedAtMs": 0, "errorCode": ""}

    def finish(self, error=""):
        if self.current:
            if self.current["callId"]:
                self.ended.append(self.current["callId"])
            self.current.update(state="ENDED", errorCode="" if error == "ended" else error)
        if self.audio_task and self.audio_task is not asyncio.current_task():
            self.audio_task.cancel()
        self.task(self.audio.close())
        self.publish()

    def start_audio(self):
        if not self.audio_task or self.audio_task.done():
            self.audio_task = self.task(self.run_audio(self.current, self.audio, self.devices))

    async def run_audio(self, call, audio, devices):
        try:
            await audio.start(*devices, call["muted"])
            await audio.watch()
            raise Failure("call_audio_unavailable")
        except (Failure, OSError):
            if self.current is call and call["state"] != "ENDED":
                self.finish("call_audio_unavailable")
                await self.reject_extra(call["callId"], hangup=True)
        except asyncio.CancelledError:
            pass

    async def stop_watch(self):
        task = self.audio_task
        if task:
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)
            if self.audio_task is task:
                self.audio_task = None

    async def reject_extra(self, cid, hangup=False):
        try:
            await self.rpc("hangupCall" if hangup else "rejectCall", {"callId": int(cid)})
        except Failure:
            if self.bridge.transport:
                self.bridge.transport.abort("transport_lost")

    async def request(self, method, params):
        b = self.bridge
        if not b.account_id or params.get("accountId") != b.account_id:
            raise Failure("account_mismatch")
        if method == "call.status":
            return self.snapshot()
        if self.lock.locked():
            raise Failure("call_busy")
        async with self.lock:
            if method == "call.dismiss":
                if self.current and self.current["state"] != "ENDED":
                    raise Failure("call_busy")
                self.current = None
                self.publish()
                return self.snapshot()
            if not self.available or b.state != "ready":
                raise Failure("call_unavailable")
            if method == "call.start":
                if self.current and self.current["state"] != "ENDED":
                    raise Failure("call_busy")
                conversation = b.store.conversation_item(b.account_id, params.get("conversationId"))
                if conversation["kind"] != "direct" or not conversation["canSend"]:
                    raise Failure("call_unavailable")
                await self.audio.close()
                if self.current and self.current["state"] != "ENDED":
                    raise Failure("call_busy")
                self.new(conversation, True)
                call = self.current
                self.publish()
                rpc, args = "startCall", {"recipient": [conversation["target"].removeprefix("aci:")]}
            else:
                cid = call_id(params.get("callId"))
                if not self.current or self.current["callId"] != cid or self.current["state"] == "ENDED":
                    raise Failure("call_not_active")
                call, audio = self.current, self.audio
                if method == "call.mute":
                    if type(params.get("muted")) is not bool:
                        raise Failure("invalid_request")
                    await self.stop_watch()
                    try:
                        await audio.mute(params["muted"])
                    except (Failure, OSError):
                        if self.current is call:
                            self.finish("call_audio_unavailable")
                        await self.reject_extra(cid, hangup=True)
                        raise Failure("call_audio_unavailable") from None
                    if self.current is not call or call["state"] == "ENDED":
                        return self.snapshot()
                    self.current["muted"] = params["muted"]
                    if self.current["state"] in ("CONNECTED", "RECONNECTING"):
                        self.start_audio()
                    self.publish()
                    return self.snapshot()
                if method in ("call.accept", "call.reject") and self.current["state"] != "RINGING_INCOMING":
                    raise Failure("call_not_active")
                rpc = {"call.accept": "acceptCall", "call.reject": "rejectCall", "call.hangup": "hangupCall"}[method]
                args = {"callId": int(cid)}
                if method == "call.accept":
                    self.accepted = True
                if method in ("call.hangup", "call.reject"):
                    await self.stop_watch()
                    await audio.close()
                    if self.current is not call or call["state"] == "ENDED":
                        return self.snapshot()
            try:
                result = await self.rpc(rpc, args)
                if self.current is not call:
                    return self.snapshot()
                if rpc == "startCall" and self.current["state"] != "ENDED":
                    if not isinstance(result, dict):
                        raise Failure("invalid_call_event")
                    cid = call_id(result.get("callId"))
                    if self.current["callId"] not in ("", cid):
                        raise Failure("invalid_call_event")
                    self.current["callId"] = cid
                    # Events may precede this response; never regress their state.
                    if self.current["state"] == "STARTING":
                        self.current["state"] = "RINGING_OUTGOING"
                if rpc in ("rejectCall", "hangupCall"):
                    self.finish()
                self.publish()
                return self.snapshot()
            except Failure as error:
                if self.current is call:
                    self.finish("call_failed")
                if call["callId"] and error.code == "rpc_error":
                    await self.reject_extra(call["callId"], hangup=True)
                if error.code not in ("rpc_error", "busy") and b.transport:
                    b.transport.abort("transport_lost")
                raise Failure("call_failed") from None

    async def close(self):
        self.available = False
        self.subscription = None
        self.subscribing = False
        self.early = []
        tasks = list(self.tasks)
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        await self.audio.close()
        self.current = None
        self.devices = (None, None)
        self.audio_task = None
        self.ended.clear()
        self.publish()
