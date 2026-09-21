"""Normalize the pinned 0.14.8 envelope; never persist the raw event stream."""
import base64
import hashlib
import json
import uuid

from signal_transport import Failure

SAFE_INT = 2**53 - 1
MAX_TEXT = 64 * 1024  # Local resource limit, not a Signal protocol limit.


class EventFailure(Failure):
    """A static source location only; never an upstream value or exception text."""
    def __init__(self, location):
        super().__init__("invalid_event")
        self.location = location


def integer(value, *, minimum=0):
    if type(value) is not int or not minimum <= value <= SAFE_INT:
        raise Failure("invalid_request")
    return value


def text(value, maximum=MAX_TEXT, *, empty=True):
    if not isinstance(value, str) or (not empty and not value):
        raise Failure("invalid_request")
    try:
        if len(value.encode("utf-8")) > maximum:
            raise Failure("invalid_request")
    except UnicodeError:
        raise Failure("invalid_request") from None
    return value


def service_id(value):
    value = text(value, 64, empty=False)
    namespace, raw = value.split(":", 1) if ":" in value else ("aci", value)
    if namespace.lower() not in ("aci", "pni"):
        raise Failure("invalid_request")
    try:
        return namespace.lower() + ":" + str(uuid.UUID(raw))
    except ValueError:
        raise Failure("invalid_request") from None


def identifier(value):
    try:
        return str(uuid.UUID(text(value, 36)))
    except ValueError:
        raise Failure("invalid_request") from None


def group_id(value):
    value = text(value, 256, empty=False)
    try:
        raw = base64.b64decode(value, validate=True)
        if not raw or base64.b64encode(raw).decode() != value:
            raise ValueError()
    except ValueError:
        raise Failure("invalid_request") from None
    return value


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False,
                                     separators=(",", ":")).encode()).hexdigest()


def message_fingerprint(body, kind, attachments):
    # Transport-local CLI IDs change between an upload and its sent sync.
    # Match metadata only under the already exact author/conversation/time key.
    aliases = {"audio/x-wav": "audio/wav", "audio/x-flac": "audio/flac", "application/ogg": "audio/ogg"}
    media = sorted((aliases.get(a["content_type"], a["content_type"]), a["size_bytes"], bool(a.get("voice_note"))) for a in attachments)
    return digest([body or "", kind, media])


def address(value, prefix):
    sid = value.get(prefix + "Uuid")
    number = value.get(prefix + "Number")
    return (service_id(sid) if sid else None,
            text(number, 128, empty=False) if number else None)


def normalize(wire, own_service_id):
    """Return bounded typed records; hidden messages never retain content."""
    try:
        return _normalize(wire, own_service_id)
    except (KeyError, TypeError, AttributeError, ValueError, Failure) as error:
        location = "signal_events"
        trace = error.__traceback__
        while trace:
            # These frames are our code. Do not include exception messages,
            # locals, wire keys, identifiers, or arbitrary filesystem paths.
            if trace.tb_frame.f_code.co_name == "_normalize":
                location = "signal_events:" + str(trace.tb_lineno)
            trace = trace.tb_next
        raise EventFailure(location) from None


def _normalize(wire, own_service_id):
    from signal_content import metadata
    if wire.get("method") != "receive":
        return []
    env = wire["params"]["result"]["envelope"]
    sender, number = address(env, "source")
    sync = env.get("syncMessage") or {}
    sent = sync.get("sentMessage")
    if sync and sender != own_service_id:
        raise Failure("invalid_event")
    output = []
    for read in sync.get("readMessages") or []:
        author, _ = address(read, "sender")
        if author:
            output.append({"kind": "read_sync", "author": author,
                           "target_ms": integer(read["timestamp"]),
                           "event_ms": integer(env["timestamp"])})
    receipt = env.get("receiptMessage")
    if receipt and sender:
        kinds = [kind for kind, field in (("delivery", "isDelivery"), ("read", "isRead"), ("viewed", "isViewed")) if receipt.get(field) is True]
        if len(kinds) != 1:
            raise Failure("invalid_event")
        kind = kinds[0]
        for timestamp in receipt.get("timestamps") or []:
            output.append({"kind": kind, "author": sender, "target_ms": integer(timestamp),
                           "event_ms": integer(receipt["when"])})
    typing = env.get("typingMessage")
    if typing and sender and sender != own_service_id:
        if typing.get("action") not in ("STARTED", "STOPPED"):
            raise Failure("invalid_event")
        output.append({"kind": "typing", "author": sender, "event_ms": integer(typing["timestamp"]),
                       "group": group_id(typing["groupId"]) if typing.get("groupId") else None,
                       "active": typing["action"] == "STARTED"})
    edit = (sent or {}).get("editMessage") if sent else env.get("editMessage")
    data = edit.get("dataMessage") if edit else sent if sent else env.get("dataMessage")
    if not data:
        return output
    author = own_service_id if sent else sender
    peer, peer_number = address(sent, "destination") if sent else (sender, number)
    group = data.get("groupInfo") or {}
    route = {"group": group_id(group["groupId"]) if group else None,
             "peer": peer, "number": peer_number,
             "title": text(group.get("groupName") or "", 1024)}
    if not route["group"] and not peer and not peer_number:
        raise Failure("invalid_event")
    common = {"route": route, "author": author, "author_number": number,
              "event_ms": integer(data["timestamp"]),
              "direction": "outgoing" if sent else "incoming",
              "origin": "phone" if sent else "remote"}
    if edit:
        hidden = bool(data.get("viewOnce"))
        body = None if hidden else text(data.get("message") or "")
        output.append({**common, "kind": "edit", "target_ms": integer(edit["targetSentTimestamp"]),
                       "body": body, "hidden": hidden, "metadata": {} if hidden else metadata(data, body),
                       "attachment_ids": [text(a["id"], 256) for a in data.get("attachments") or []]})
        return output
    if data.get("remoteDelete"):
        output.append({**common, "kind": "delete", "target_ms": integer(data["remoteDelete"]["timestamp"])})
        return output
    if data.get("reaction"):
        reaction = data["reaction"]
        target_author = reaction.get("targetAuthorUuid")
        if target_author:
            output.append({**common, "kind": "reaction", "actor": author,
                           "author": service_id(target_author),
                           "target_ms": integer(reaction["targetSentTimestamp"]),
                           "emoji": text(reaction["emoji"], 128, empty=False),
                           "removed": reaction.get("isRemove") is True})
        return output
    expiration = integer(data.get("expiresInSeconds", 0))
    if data.get("isExpirationUpdate"):
        output.append({**common, "kind": "expiration_update", "expiration_seconds": expiration})
        return output
    unsupported = "view_once_unsupported" if data.get("viewOnce") else None
    attachments = []
    if not unsupported:
        for item in data.get("attachments") or []:
            attachments.append({"cli_id": text(item["id"], 256, empty=False),
                                "content_type": text(item.get("contentType") or "application/octet-stream", 256),
                                "filename": text(item.get("filename") or "Załącznik", 1024),
                                "voice_note": item.get("isVoiceNote") is True,
                                "size_bytes": integer(item.get("size", 0))})
        if len(attachments) > 100:
            raise Failure("invalid_event")
    body = None if unsupported or data.get("message") is None else text(data["message"])
    kind = unsupported or ("media" if attachments else "text" if body is not None else "event")
    output.append({**common, "kind": "message", "message_kind": kind, "body": body,
                   "attachments": attachments, "expiration_seconds": expiration,
                   "expiration_start_ms": integer(sent.get("expirationStartTimestamp") or data["timestamp"]) if sent and expiration else 0,
                   "metadata": {} if unsupported else metadata(data, body),
                   "source_device": integer(env["sourceDevice"]) if env.get("sourceDevice") is not None else None,
                   "server_received_ms": integer(env["serverReceivedTimestamp"]) if env.get("serverReceivedTimestamp") is not None else None})
    return output
