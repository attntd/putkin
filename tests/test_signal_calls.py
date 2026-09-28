"""Calls through the real bridge/transport/store, with explicitly synthetic audio."""
import json
from pathlib import Path
import time
import unittest

import test_signal_history as history
import test_signal_messages as messages
import test_signal_groups as groups
from test_signal_interactions import typing


def incoming(cid=9223372036854775807, state="RINGING_INCOMING"):
    return {"callId": cid, "state": state, "uuid": history.PEER, "isOutgoing": False,
            "inputDeviceName": "signal_input_" + str(cid), "outputDeviceName": "signal_output_" + str(cid)}


class CallsTests(unittest.TestCase):
    setUp = history.BridgeHistoryTests.setUp
    tearDown = history.BridgeHistoryTests.tearDown
    start = history.BridgeHistoryTests.start
    request = history.BridgeHistoryTests.request
    error = messages.MessagingTests.error

    def ready(self, **scenario):
        client = self.start(**scenario)
        account = client.state("ready")["data"]["accountId"]
        conversation = self.request(client, "conversation.open", {"kind": "direct", "serviceId": history.PEER})
        return client, {"accountId": account, "conversationId": conversation["conversationId"]}

    def records(self, kind):
        return [v for v in map(json.loads, self.record.read_text().splitlines()) if v["kind"] == kind]

    def state(self, client, params, expected):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            value = self.request(client, "call.status", params)
            if value["call"] and value["call"]["state"] == expected:
                return value["call"]
            time.sleep(.02)
        self.fail(f"Expected call state {expected}: {value}")

    def test_outgoing_large_signed_id_mute_hangup_and_one_subscription(self):
        client, params = self.ready()
        result = self.request(client, "call.start", params)
        call = self.state(client, params, "CONNECTED")
        self.assertEqual(call["callId"], "-9223372036854775807")
        self.assertNotIn("inputDeviceName", result["call"])
        self.assertGreater(call["connectedAtMs"], 0)
        target = dict(params, callId=call["callId"])
        self.error(client, "call.start", params, "call_busy")
        self.request(client, "call.mute", dict(target, muted=True))
        self.assertTrue(self.request(client, "call.status", params)["call"]["muted"])
        self.request(client, "call.mute", dict(target, muted=False))
        self.request(client, "call.hangup", target)
        self.state(client, params, "ENDED")
        self.assertEqual(self.records("hangupCall")[0]["params"]["callId"], -9223372036854775807)
        self.assertEqual(len(self.records("subscribeCallEvents")), 1)
        self.assertEqual(len(self.records("startCall")), 1)
        self.assertTrue(self.records("call-audio-stop"))
        self.request(client, "call.dismiss", params)
        self.assertIsNone(self.request(client, "call.status", params)["call"])

    def test_typing_preference_preserves_receiver_call_and_stops_ephemeral_typing(self):
        config = Path(self.env["XDG_CONFIG_HOME"]) / "putkin/signal.json"
        config.parent.mkdir(mode=0o700)
        config.write_text(json.dumps({"v": 1, "enabled": True, "executable": "signal-cli"}))
        config.chmod(0o600)
        client, params = self.ready()
        self.request(client, "call.start", params)
        call = self.state(client, params, "CONNECTED")
        processes = self.records("start")
        client.frames = [v for v in client.frames if v.get("name") != "service.changed"]
        for enabled in (True, False, True):
            self.request(client, "account.configure", {"typingIndicators": enabled})
            changed = client.read(lambda v: v.get("name") == "service.changed"
                and v["data"]["configuration"]["typingIndicators"] == enabled)
            self.assertEqual(changed["data"]["serviceState"], "ready")
            status = self.request(client, "service.status")
            self.assertEqual(status["serviceState"], "ready")
            self.assertEqual(status["errorCode"], "")
            self.assertEqual(self.request(client, "call.status", params)["call"], call)
            self.assertEqual(self.records("start"), processes)
            self.assertEqual(json.loads(config.read_text())["typingIndicators"], enabled)
            if enabled:
                self.request(client, "typing.set", dict(params, active=True))
                self.request(client, "test.echo", {"receive": typing()})
                update = client.read(lambda v: v.get("name") == "typing.changed")
                self.assertTrue(update["data"]["authors"])
            else:
                update = client.read(lambda v: v.get("name") == "typing.changed")
                self.assertEqual(update["data"]["authors"], [])
                self.assertEqual([r["params"]["stop"] for r in self.records("typing")], [False, True])
                self.request(client, "typing.set", dict(params, active=True))
                self.assertEqual(len(self.records("typing")), 2)
        self.assertEqual(len(self.records("subscribe")), 1)
        self.assertEqual(len(self.records("subscribeCallEvents")), 1)
        self.assertFalse(self.records("call-audio-stop"))
        client.close()
        restored = self.start()
        self.assertTrue(restored.state("ready")["data"]["configuration"]["typingIndicators"])
        self.assertIsNone(self.request(restored, "call.status", params)["call"])

    def test_incoming_before_subscription_reply_does_not_open_microphone_until_accepted(self):
        client, params = self.ready(incomingCalls=[incoming()])
        call = self.state(client, params, "RINGING_INCOMING")
        self.assertEqual(call["callId"], "9223372036854775807")
        self.assertFalse(self.records("call-audio-start"))
        self.request(client, "call.accept", dict(params, callId=call["callId"]))
        self.state(client, params, "CONNECTED")
        self.assertTrue(self.records("call-audio-start"))
        client.close()
        self.assertTrue(self.records("call-audio-stop"))

    def test_reject_never_opens_audio_and_late_connected_cannot_revive_call(self):
        client, params = self.ready(incomingCalls=[incoming()])
        self.request(client, "call.reject", dict(params, callId=str(9223372036854775807)))
        late = {"jsonrpc": "2.0", "method": "callEvent", "params": {"subscription": 1, "result": incoming(state="CONNECTED")}}
        self.request(client, "test.echo", {"receive": late})
        self.state(client, params, "ENDED")
        self.assertFalse(self.records("call-audio-start"))
        self.assertEqual(len(self.records("rejectCall")), 1)

    def test_groups_notes_wrong_account_and_stale_ids_do_not_reach_cli(self):
        client, params = self.ready(groups=[groups.group()])
        self.error(client, "call.start", dict(params, accountId="wrong"), "account_mismatch")
        note = self.request(client, "conversation.open", {"kind": "note"})
        self.error(client, "call.start", dict(params, conversationId=note["conversationId"]), "call_unavailable")
        group = self.request(client, "conversation.open", {"kind": "group", "groupId": history.GROUP})
        self.error(client, "call.start", dict(params, conversationId=group["conversationId"]), "call_unavailable")
        self.error(client, "call.hangup", dict(params, callId="9007199254740993"), "call_not_active")
        self.assertFalse(self.records("startCall"))

    def test_audio_failure_ends_call_without_disabling_messages(self):
        client, params = self.ready(callAudioFail=True)
        self.request(client, "call.start", params)
        call = self.state(client, params, "ENDED")
        self.assertEqual(call["errorCode"], "call_audio_unavailable")
        self.assertEqual(self.request(client, "service.status")["serviceState"], "ready")
        deadline = time.monotonic() + 3
        while not self.records("hangupCall") and time.monotonic() < deadline:
            time.sleep(.02)
        self.assertEqual(len(self.records("hangupCall")), 1)

    def test_remote_end_and_cli_restart_never_replay_outgoing_call(self):
        client, params = self.ready(outgoingCallStates=["RINGING_OUTGOING", "ENDED"])
        self.request(client, "call.start", params)
        self.state(client, params, "ENDED")
        self.request(client, "account.configure", {"enabled": False})
        client.state("disabled")
        self.assertIsNone(self.request(client, "call.status", params)["call"])
        self.assertEqual(len(self.records("startCall")), 1)

    def test_consecutive_incoming_calls_keep_independent_audio(self):
        client, params = self.ready(incomingCalls=[incoming()])
        for cid in (9223372036854775807, 9007199254740993):
            if cid != 9223372036854775807:
                self.request(client, "test.echo", {"receive": {"jsonrpc": "2.0", "method": "callEvent",
                    "params": {"subscription": 1, "result": incoming(cid)}}})
            self.request(client, "call.accept", dict(params, callId=str(cid)))
            self.state(client, params, "CONNECTED")
            self.request(client, "call.hangup", dict(params, callId=str(cid)))
            self.assertEqual(self.state(client, params, "ENDED")["errorCode"], "")
        self.assertEqual(len(self.records("call-audio-start")), 2)
        self.assertEqual(len(self.records("call-audio-stop")), 2)
        self.assertEqual(len(self.records("hangupCall")), 2)

    def test_mute_failure_stops_audio_and_call(self):
        client, params = self.ready(callMuteFail=True)
        self.request(client, "call.start", params)
        call = self.state(client, params, "CONNECTED")
        self.error(client, "call.mute", dict(params, callId=call["callId"], muted=False), "call_audio_unavailable")
        self.assertEqual(self.state(client, params, "ENDED")["errorCode"], "call_audio_unavailable")
        self.assertTrue(self.records("call-audio-stop"))
        self.assertEqual(len(self.records("hangupCall")), 1)

    def test_rpc_error_does_not_retry_start(self):
        client, params = self.ready(callError="startCall")
        self.error(client, "call.start", params, "call_failed")
        self.state(client, params, "ENDED")
        self.assertEqual(len(self.records("startCall")), 1)
        self.assertFalse(self.records("call-audio-start"))

    def test_late_hangup_response_does_not_end_next_incoming_call(self):
        client, params = self.ready(callDelay=.3)
        self.request(client, "call.start", params)
        call = self.state(client, params, "CONNECTED")
        client.send("ending", "call.hangup", dict(params, callId=call["callId"]))
        self.state(client, params, "ENDED")
        self.request(client, "test.echo", {"receive": {"jsonrpc": "2.0", "method": "callEvent",
            "params": {"subscription": 1, "result": incoming()}}})
        self.assertNotIn("error", client.reply("ending"))
        self.assertEqual(self.state(client, params, "RINGING_INCOMING")["callId"], "9223372036854775807")
        self.assertEqual(len(self.records("hangupCall")), 1)


if __name__ == "__main__":
    unittest.main()
