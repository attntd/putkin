#!/usr/bin/env python3
"""Explicit, scripted JSON-RPC peer. Only synthetic fixtures, no Signal client.

S00 supplies framing/examples. Fault injection and lifecycle ownership belong
to S01; account/message semantics belong to S02 and later stages.
"""

import argparse
import asyncio
import json
import os
from pathlib import Path
import signal
import sys
import time


MAX_REQUEST_BYTES = 1024 * 1024  # Test harness limit, not a Signal limit.


def replay(fixture, source, destination, chunk_bytes=0):
    if fixture.get("format") != 1 or fixture.get("synthetic") is not True:
        raise ValueError("Expected an explicitly synthetic format 1 fixture")
    events = {event["name"]: event["wire"] for event in fixture["events"]}
    exchanges = iter(fixture["exchanges"])
    expected = next(exchanges, None)

    def emit(frame):
        data = (json.dumps(frame, ensure_ascii=False, separators=(",", ":")) + "\n").encode()
        size = chunk_bytes or len(data)
        for start in range(0, len(data), size):
            destination.write(data[start:start + size])
            destination.flush()

    while True:
        raw = source.readline(MAX_REQUEST_BYTES + 1)
        if not raw:
            if expected is not None:
                raise ValueError("EOF before the scripted conversation completed")
            return
        if len(raw) > MAX_REQUEST_BYTES or not raw.endswith(b"\n"):
            raise ValueError("Oversized or incomplete request frame")
        request = json.loads(raw)
        if not isinstance(request, dict) or request.get("jsonrpc") != "2.0" or "id" not in request:
            raise ValueError("Expected a JSON-RPC 2.0 request with id")
        if expected is None or request.get("method") != expected["method"] or request.get("params", {}) != expected.get("params", {}):
            # A mismatch is a failed test, never a simulated upstream success.
            raise ValueError("Request does not match the scripted method/params")
        for name in expected.get("beforeResponseEvents", []):
            emit(events[name])
        reply = {"jsonrpc": "2.0", "id": request["id"]}
        key = "error" if "error" in expected else "result"
        reply[key] = expected[key]
        emit(reply)
        for name in expected.get("afterResponseEvents", []):
            emit(events[name])
        expected = next(exchanges, None)


async def lifecycle(fixture):
    """Synthetic fault peer. Production never discovers this mode implicitly."""
    if fixture.get("format") != 1 or fixture.get("synthetic") is not True:
        raise ValueError("Expected synthetic fixture")
    if "--version" in sys.argv:
        print("signal-cli " + fixture.get("version", "0.14.8"), flush=True)
        return
    if fixture.get("ignoreTerm"):
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
    def record(kind, params=None):
        if fixture.get("record"):
            with open(fixture["record"], "a") as destination:
                destination.write(json.dumps({"kind": kind, "pid": os.getpid(), **({"params": params} if params else {})}) + "\n")
    record("start")
    print("SYNTHETIC_PRIVATE_STDERR", file=sys.stderr, flush=True)
    reader = asyncio.StreamReader(limit=MAX_REQUEST_BYTES)
    pipe, _ = await asyncio.get_running_loop().connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin.buffer)
    tasks = set()
    linked_file = Path(fixture["linkedFile"]) if fixture.get("linkedFile") else None
    link_uri = None
    writer_lock = asyncio.Lock()
    default_own = {"number": "+12025550100", "uuid": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "messageExpirationTime": 0, "profileSharing": True}
    default_peer = {"number": "+12025550101", "uuid": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "messageExpirationTime": fixture.get("expiration", 0), "profileSharing": True}
    fixture['contacts'] = [dict({'profileSharing': True}, **c) for c in fixture.get('contacts', [default_own, default_peer])]
    for g in fixture.get('groups', []):
        for k, v in {'isMember': True, 'isTerminated': False, 'isBlocked': False, 'permissionSendMessage': 'EVERY_MEMBER', 'permissionAddMember': 'ONLY_ADMINS', 'permissionEditDetails': 'ONLY_ADMINS', 'members': [], 'admins': [], 'pendingMembers': [], 'requestingMembers': [], 'messageExpirationTime': 0}.items(): g.setdefault(k, v)
    if fixture.get('directoryFile') and Path(fixture['directoryFile']).exists():
        fixture.update(json.loads(Path(fixture['directoryFile']).read_text()))
    async def emit(value):
        raw = (json.dumps(value, ensure_ascii=False) + "\n").encode()
        async with writer_lock:
            step = fixture.get("chunkBytes") or len(raw)
            for offset in range(0, len(raw), step):
                os.write(sys.stdout.fileno(), raw[offset:offset + step])
                if fixture.get("chunkDelay"):
                    await asyncio.sleep(fixture["chunkDelay"])
    async def respond(request):
        nonlocal link_uri
        method, params = request["method"], request.get("params", {})
        await asyncio.sleep(params.get("delay", fixture.get("delay", 0)))
        if method == "listAccounts":
            record("accounts")
            result = ([{"number": "+12025550100"}] if linked_file and linked_file.exists()
                      else fixture.get("accounts", [{"number": "+12025550100"}]))
            if fixture.get("revokedFile") and Path(fixture["revokedFile"]).exists():
                result = []
        elif method == "startLink":
            record("link-start")
            import secrets
            from urllib.parse import urlencode
            # Ephemeral even in tests: never part of a fixture or record.
            link_uri = "sgnl://linkdevice?" + urlencode({"uuid": secrets.token_hex(16), "pub_key": secrets.token_urlsafe(44)})
            if fixture.get("linkStartDelay"):
                await asyncio.sleep(fixture["linkStartDelay"])
            result = {"deviceLinkUri": link_uri}
        elif method == "finishLink":
            record("link-finish")
            if not link_uri or params.get("deviceLinkUri") != link_uri or not params.get("deviceName"):
                raise ValueError("Invalid synthetic link request")
            gate = fixture.get("linkGate")
            while gate and not Path(gate).exists():
                await asyncio.sleep(.03)
            if linked_file:
                linked_file.touch(mode=0o600)
            if fixture.get("linkCrash"):
                os._exit(23)
            await asyncio.sleep(fixture.get("linkFinishDelay", 0))
            result = {"number": "+12025550100"}
            link_uri = None
        elif method == "sendSyncRequest":
            record("sync")
            result = {}
        elif method == "listContacts":
            if fixture.get('directoryFile') and Path(fixture['directoryFile']).exists():
                fixture.update(json.loads(Path(fixture['directoryFile']).read_text()))
            record("contacts")
            own = {"number": "+12025550100", "uuid": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "messageExpirationTime": 0}
            peer = {"number": "+12025550101", "uuid": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "messageExpirationTime": fixture.get("expiration", 0)}
            result = [v for v in fixture.get("contacts", [own, peer]) if not params.get("recipient") or
                      v.get("number") in params["recipient"] or v.get("uuid") in params["recipient"]]
        elif method == "getUserStatus":
            record("resolve")
            query = (params.get("recipient") or params.get("username") or [""])[0]
            result = fixture.get("resolved", [{"recipient": query, "number": query if query.startswith("+") else None,
                "username": None if query.startswith("+") else query, "uuid": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "isRegistered": True}])
        elif method == "listGroups":
            record("groups")
            if fixture.get('directoryFile') and Path(fixture['directoryFile']).exists():
                fixture.update(json.loads(Path(fixture['directoryFile']).read_text()))
            result = [g for g in fixture.get("groups", []) if not params.get('groupId') or g['id'] in params['groupId']]
        elif method == "subscribeReceive":
            record("subscribe")
            sample = json.loads(Path(__file__).with_name("fixtures").joinpath("signal/v0.14.8/session.json").read_text())
            event = sample["events"][0]["wire"]
            event["params"]["result"]["envelope"]["dataMessage"]["message"] = "Zażółć 🐈\nwiersz"
            for event in fixture.get("receiveEvents", [event]):
                await emit(event)
            result = 0
        elif method in ("updateGroup", "joinGroup", "quitGroup") and "expiration" not in params:
            record(method, params)
            if fixture.get('groupError'):
                await emit({"jsonrpc": "2.0", "id": request['id'], "error": {"code": -3}})
                return
            groups = fixture.setdefault('groups', [])
            target = params.get('groupId') or fixture.get('createdGroupId', 'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=')
            group = next((g for g in groups if g['id'] == target), None)
            created = group is None
            if created:
                group = {'id': target, 'name': params.get('name', 'Dołączona grupa'), 'description': '', 'isMember': not fixture.get('onlyRequested', False),
                    'isBlocked': False, 'isTerminated': False, 'members': [{'uuid': default_own['uuid'], 'isAdmin': method == 'updateGroup'}], 'admins': [],
                    'pendingMembers': [], 'requestingMembers': [{'uuid': default_own['uuid']}] if fixture.get('onlyRequested') else [],
                    'banned': [], 'messageExpirationTime': 0, 'permissionAddMember': 'ONLY_ADMINS', 'permissionEditDetails': 'ONLY_ADMINS', 'permissionSendMessage': 'EVERY_MEMBER'}
                groups.append(group)
            for key in ('name', 'description'):
                if key in params: group[key] = params[key]
            if 'avatar' in params and not Path(params['avatar']).is_file(): raise ValueError('Missing staged avatar')
            for sid in params.get('member', []):
                if not any(m.get('uuid') == sid for m in group['members']): group['members'].append({'uuid': sid, 'isAdmin': False})
                for key in ('pendingMembers', 'requestingMembers'): group[key] = [m for m in group[key] if m.get('uuid') != sid]
            for key in ('members', 'pendingMembers', 'requestingMembers'): group[key] = [m for m in group[key] if m.get('uuid') not in params.get('removeMember', [])]
            for member in group['members']:
                if member.get('uuid') in params.get('admin', []): member['isAdmin'] = True
                if member.get('uuid') in params.get('removeAdmin', []): member['isAdmin'] = False
            for key, field in [('setPermissionAddMember', 'permissionAddMember'), ('setPermissionEditDetails', 'permissionEditDetails'), ('setPermissionSendMessages', 'permissionSendMessage')]:
                if key in params: group[field] = params[key].upper().replace('-', '_')
            if 'link' in params: group['groupInviteLink'] = '' if params['link'] == 'disabled' else 'https://signal.group/#SYNTHETIC_LINK_1234567890'
            if method == 'quitGroup':
                group['isMember'] = False
                for key in ('members', 'pendingMembers', 'requestingMembers'): group[key] = [m for m in group[key] if m.get('uuid') != default_own['uuid']]
            elif method == 'updateGroup' and not group['isMember']:
                group['isMember'] = True; group['pendingMembers'] = []
            if fixture.get('directoryFile'): Path(fixture['directoryFile']).write_text(json.dumps({'contacts': fixture['contacts'], 'groups': groups}))
            if fixture.get('groupCrash'): os._exit(23)
            await asyncio.sleep(fixture.get('groupDelay', 0))
            result = {'timestamp': int(time.time() * 1000), 'results': fixture.get('groupResults', [])}
            if created or method == 'joinGroup': result['groupId'] = target
            if fixture.get('onlyRequested') and method == 'joinGroup': result['onlyRequested'] = True
        elif method in ('sendMessageRequestResponse', 'block', 'unblock'):
            record(method, params)
            for c in fixture['contacts']:
                if c.get('uuid') in params.get('recipient', []):
                    if method == 'sendMessageRequestResponse': c['profileSharing'] = params['type'] == 'accept'
                    else: c['isBlocked'] = method == 'block'
            for g in fixture.get('groups', []):
                if g['id'] in params.get('groupId', []): g['isBlocked'] = method == 'block'
            result = {}
        elif method == 'getAvatar':
            record(method, params)
            import base64
            data = Path(__file__).with_name('fixtures') / 'signal/media/image.png'
            result = {'data': base64.b64encode(data.read_bytes()).decode()}
        elif method in ("updateContact", "updateGroup"):
            if type(params.get("expiration")) is not int or (method == "updateContact" and not isinstance(params.get("recipient"), str)) or (method == "updateGroup" and not isinstance(params.get("groupId"), str)):
                await emit({"jsonrpc": "2.0", "id": request["id"], "error": {"code": -32602}})
                return
            fixture["expiration"] = params["expiration"]
            for contact in fixture.get("contacts", []):
                if contact.get("uuid") == params.get("recipient"):
                    contact["messageExpirationTime"] = params["expiration"]
            record("expiration", params)
            result = {}
        elif method == "remoteDelete":
            if type(params.get("targetTimestamp")) is not int or "message" in params or not any(k in params for k in ("recipient", "groupId", "noteToSelf")):
                await emit({"jsonrpc": "2.0", "id": request["id"], "error": {"code": -32602}})
                return
            record("delete", params)
            result = {"timestamp": int(time.time() * 1000), "results": [{"recipientAddress": {"uuid": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}, "type": "SUCCESS"}]}
        elif method == "sendTyping":
            record("typing", params)
            result = {"timestamp": 1790000003000, "results": []}
        elif method == "sendReaction" or (method == "send" and "editTimestamp" in params):
            record("reaction" if method == "sendReaction" else "edit", params)
            if fixture.get("interactionError"):
                await emit({"jsonrpc": "2.0", "id": request["id"], "error": {"code": -3}})
                return
            result = {"timestamp": fixture.get("interactionTimestamp", 1790000009000), "results": [{"recipientAddress": {"uuid": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}, "type": "SUCCESS"}]}
        elif method == "send":
            record("send", {k: params[k] for k in ("groupId", "recipient", "noteToSelf") if k in params})
            if params.get("attachment"):
                paths = params["attachment"]
                if not isinstance(paths, list) or not 1 <= len(paths) <= 8 or any(not Path(p).is_file() for p in paths):
                    await emit({"jsonrpc": "2.0", "id": request["id"], "error": {"code": -32602}})
                    return
                record("media-send", {"files": [{"name": Path(p).name, "size": Path(p).stat().st_size} for p in paths]})
            for event in fixture.get("beforeSendReply", []):
                await emit(event)
            if fixture.get("sendCrash"):
                os._exit(23)
            await asyncio.sleep(fixture.get("sendDelay", 0))
            if fixture.get("sendError"):
                await emit({"jsonrpc": "2.0", "id": request["id"], "error": {"code": -3, "data": "SYNTHETIC_PRIVATE_ERROR"}})
                return
            result = fixture.get("sendResult", {"timestamp": 1790000002000, "results": [{
                "recipientAddress": {"uuid": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "number": "+12025550101"}, "type": "SUCCESS"}]})
            result["expiresInSeconds"] = fixture.get("expiration", 0)
        elif method == "sendReceipt":
            if (set(params) != {"account", "recipient", "targetTimestamp", "type"}
                    or params["account"] != "+12025550100" or params["type"] != "read"
                    or not isinstance(params["recipient"], str) or not isinstance(params["targetTimestamp"], list)
                    or not 1 <= len(params["targetTimestamp"]) <= 100
                    or any(type(t) is not int for t in params["targetTimestamp"])):
                await emit({"jsonrpc": "2.0", "id": request["id"], "error": {"code": -32602}})
                return
            record("receipt", params)
            if fixture.get("receiptCrash"):
                os._exit(23)
            await asyncio.sleep(fixture.get("receiptDelay", 0))
            result = {"timestamp": 1790000200000, "results": [] if fixture.get("readReceipts") is False else [{
                "recipientAddress": {"uuid": params["recipient"]}, "type": "SUCCESS"}]}
        elif method == "echo" and params.get("receive"):
            await emit(params["receive"])
            result = {"accepted": True}
        elif method in ("echo", "mutate"):
            record(method)
            result = params
        else:
            await emit({"jsonrpc": "2.0", "id": request["id"], "error": {"code": -32601, "message": "SYNTHETIC_PRIVATE_ERROR"}})
            return
        if params.get("fault") == "crash":
            os._exit(23)
        fault = params.get("fault", fixture.get("fault") if method == "subscribeReceive" else None)
        if fault:
            raw = {"malformed": b"{bad}\n", "oversized": b"x" * (MAX_REQUEST_BYTES + 1),
                   "truncated": b'{"jsonrpc":', "invalidUtf8": b'\xff\n'}.get(fault)
            if raw:
                os.write(sys.stdout.fileno(), raw)
                if fault == "truncated":
                    os._exit(0)
                return
        await emit({"jsonrpc": "2.0", "id": request["id"], "result": result})
        if method == "send":
            for event in fixture.get("afterSendReply", []):
                await emit(event)
        if method == "subscribeReceive" and fixture.get("crashAfterSubscribe"):
            await asyncio.sleep(.05)
            os._exit(23)
    try:
        while raw := await reader.readline():
            task = asyncio.create_task(respond(json.loads(raw)))
            tasks.add(task)
            task.add_done_callback(tasks.discard)
        if fixture.get("ignoreEof"):
            await asyncio.Event().wait()
        await asyncio.gather(*tasks)
    finally:
        pipe.close()
        record("exit")


def main():
    if "--lifecycle-scenario" in sys.argv:
        scenario = Path(sys.argv[sys.argv.index("--lifecycle-scenario") + 1])
        try:
            asyncio.run(lifecycle(json.loads(scenario.read_text())))
        except (OSError, ValueError, KeyError, TypeError):
            return 2
        return 0
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", required=True, type=Path)
    parser.add_argument("--chunk-bytes", type=int, default=0)
    args = parser.parse_args()
    if args.chunk_bytes < 0:
        parser.error("--chunk-bytes must be non-negative")
    try:
        replay(json.loads(args.scenario.read_text()), sys.stdin.buffer, sys.stdout.buffer, args.chunk_bytes)
    except (OSError, ValueError, KeyError, TypeError) as error:
        # No request body, phone number or other payload in diagnostics.
        print(f"Synthetic signal-cli peer failed: {type(error).__name__}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
