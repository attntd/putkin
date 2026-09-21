"""Putkin Signal IPC v1: owned transport, durable history and shared outbox."""
import argparse
import asyncio
import os
import re
from pathlib import Path
import shutil
import signal
import sqlite3
import sys
import uuid
import signal_replies
import signal_receipts
import signal_retention
import signal_directory
from signal_groups import Groups, CAPABILITIES as GROUP_CAPABILITIES

from signal_paths import StoreLease, directory
from signal_account import Account, CAPABILITIES as ACCOUNT_CAPABILITIES, DEFAULT_CONFIG
from signal_events import EventFailure, integer, service_id, text
from signal_outbox import Outbox
from signal_typing import Typing
from signal_process import parent_death
from signal_store import CAPABILITIES, SCHEMA_VERSION, Store
from signal_transport import Failure, MAX_FRAME, RpcTransport, encode, frame, spawn, version

BACKOFF = (1, 2, 4, 8, 16)
FATAL = {"unsupported_version", "cli_unavailable", "invalid_frame", "incomplete_frame",
         "frame_too_large", "multiple_accounts", "unsafe_path", "invalid_config", "invalid_event",
         "account_identity_unknown", "unsupported_schema", "storage_error", "overloaded", "relink_required",
         "qr_unavailable", "qr_error", "invalid_link", "media_policy_required", "incompatible_release", "runtime_invalid"}


class Output:
    """Bounded nonblocking pipe. A stalled/disconnected QML cannot hang cleanup."""
    def __init__(self, stop):
        self.loop = asyncio.get_running_loop()
        self.stop = stop
        self.buffer = bytearray()
        self.fd = sys.stdout.fileno()
        os.set_blocking(self.fd, False)

    def emit(self, value):
        raw = encode(value)
        if len(self.buffer) + len(raw) > 4 * MAX_FRAME:
            self.stop.set()
            return
        self.buffer.extend(raw)
        self.loop.add_writer(self.fd, self.flush)

    def flush(self):
        try:
            count = os.write(self.fd, self.buffer)
            del self.buffer[:count]
        except BlockingIOError:
            return
        except (BrokenPipeError, OSError):
            self.buffer.clear()
            self.stop.set()
        if not self.buffer:
            self.loop.remove_writer(self.fd)


class Bridge:
    def __init__(self, args):
        self.args = args
        self.stop = asyncio.Event()
        self.retry = asyncio.Event()
        self.output = Output(self.stop)
        self.generation = uuid.uuid4().hex
        self.sequence = 0
        self.account_state = "unlinked"
        self.state = "starting"
        self.error = ""
        self.event_error_location = ""
        self.cli_version = ""
        self.transport = None
        self.requests = {}
        self.attempts = 0
        self.store = None
        self.outbox = None
        self.account_id = ""
        self.wake_outbox = asyncio.Event()
        self.sender = None
        self.retention_timer = None
        self.lease = None
        self.restart = asyncio.Event()
        self.account = Account(self)
        self.directory_task = None
        self.directory_dirty = False
        self.media_lock = asyncio.Lock()
        self.media_task = None
        self.typing = Typing(self)
        self.mutation_lock = asyncio.Lock()
        self.groups = Groups(self)

    def snapshot(self):
        return {"ipcVersion": 1, "schemaVersion": SCHEMA_VERSION if self.store else 0, "cliVersion": self.cli_version,
                "accountId": self.account_id,
                "accountState": self.account_state, "serviceState": self.state,
                "errorCode": self.error, "eventErrorLocation": self.event_error_location,
                "retryCount": self.attempts, **self.account.snapshot(),
                "capabilities": ["service.status", "service.retry", "request.cancel"]
                + (ACCOUNT_CAPABILITIES if self.lease and self.store and self.store.healthy else [])
                + (["recipient.resolve"] if self.state == "ready" and self.account_id else [])
                + (GROUP_CAPABILITIES if self.store and self.store.healthy and self.account_id else [])
                + (CAPABILITIES if self.store and self.store.healthy and self.account_id else [])
                + (["test.echo", "test.mutate", "test.receive", "test.metrics"] if self.args.test_scenario else [])}

    def emit(self, kind, **values):
        self.output.emit({"v": 1, "type": kind, "generation": self.generation, **values})

    def event(self, name, data):
        self.sequence += 1
        self.emit("event", seq=str(self.sequence), name=name, data=data)

    def status(self, state, error=""):
        self.state, self.error = state, error
        if state != "ready":
            self.typing.clear()
        self.event("service.changed", self.snapshot())

    def incoming(self, value):
        if value["method"] == "receive":
            if not self.store or not self.account_id:
                raise Failure("storage_not_ready")
            params = value["params"]
            if not isinstance(params.get("result"), dict) or "envelope" not in params["result"]:
                raise Failure("invalid_frame")
            try:
                self.store.receive(self.account_id, value)
                self.typing.receive(value)
                self.import_media()
                self.schedule_cleanup()
                sync = params["result"]["envelope"].get("syncMessage") or {}
                envelope = params["result"]["envelope"]
                data = envelope.get("dataMessage") or sync.get("sentMessage") or {}
                if "syncMessage" in envelope or data.get("groupInfo") or envelope.get("sourceUuid"):
                    self.refresh_directory()
            except EventFailure as error:
                self.event_error_location = error.location
                raise
            except sqlite3.Error:
                raise Failure("storage_error") from None
            if self.args.test_scenario:
                # Test-only marker contains no envelope/body and follows COMMIT.
                self.event("test.receive", {"committed": True})
        # Unknown, valid future notifications are ignored, never interpreted as RPC results.

    async def media_worker(self, function, *args, **kwargs):
        task = asyncio.create_task(asyncio.to_thread(function, *args, **kwargs))
        try:
            return await asyncio.shield(task)
        except asyncio.CancelledError:
            # A thread cannot be cancelled. Join before releasing IDs/lease.
            await asyncio.gather(task, return_exceptions=True)
            raise

    def import_media(self):
        if self.media_task and not self.media_task.done():
            return
        async def receive_files():
            async with self.media_lock:
                media = self.store.media
                while self.account_id:
                    pending = media.pending(self.account_id)
                    if not pending: break
                    row = pending[0]
                    aid = row["attachment_id"]
                    media.active.add(aid)
                    try:
                        prepared = await self.media_worker(media.prepare, str(media.source(row["cli_id"])), aid,
                            name=row["filename"], declared=row["content_type"], size=row["size_bytes"])
                        media.imported(self.account_id, aid, prepared)
                    except Failure as error:
                        if error.code == "storage_error":
                            self.storage_failed(); return
                        media.imported(self.account_id, aid, error=error.code)
                    finally:
                        media.active.discard(aid)
                        media.gc()
                    try: media.release_cli(row["cli_id"])
                    except (Failure, OSError):
                        self.storage_failed(); return
        self.media_task = asyncio.create_task(receive_files())

    async def media_request(self, method, params):
        from signal_media import MAX_FILES, TYPES, local_path
        if not self.store or not self.store.healthy:
            raise Failure("storage_error")
        account = self.account_id
        if not account or params.get("accountId") != account:
            raise Failure("account_mismatch")
        media = self.store.media
        async with self.media_lock:
            cid = params.get("conversationId")
            if method == "attachment.remove":
                return media.remove(account, cid, params.get("attachmentId"))
            if method in ("attachment.stage", "attachment.paste"):
                if not self.store.conversation_item(account, cid)["canSetExpiration"]:
                    raise Failure("send_unavailable")
                sources = params.get("paths", [])
                if method == "attachment.stage" and (not isinstance(sources, list) or not 1 <= len(sources) <= MAX_FILES):
                    raise Failure("attachment_limit")
                prepared, owned = [], []
                try:
                    if method == "attachment.paste":
                        aid = str(uuid.uuid4()); owned.append(aid); media.active.add(aid)
                        prepared.append(await self.media_worker(media.paste, aid))
                    else:
                        for path in sources:
                            aid = str(uuid.uuid4()); owned.append(aid); media.active.add(aid)
                            prepared.append(await self.media_worker(media.prepare, path, aid))
                    if account != self.account_id:
                        raise Failure("account_mismatch")
                    return media.stage(account, cid, prepared)
                finally:
                    media.active.difference_update(owned)
                    media.gc()
            item = media.item(account, params.get("attachmentId"))
            if item["state"] != "ready":
                raise Failure("attachment_unavailable")
            if method == "attachment.save":
                await self.media_worker(media.save, item["url"], params.get("destination"))
                return {"saved": True}
            if method == "attachment.open":
                # Only recognized inert formats; arbitrary files may be saved.
                if item["content_type"] not in TYPES:
                    raise Failure("attachment_unsafe")
                return {"url": item["url"]}
        raise Failure("unsupported_method")

    def refresh_directory(self):
        self.directory_dirty = True
        if self.directory_task and not self.directory_task.done():
            return
        async def refresh():
            try:
                while self.directory_dirty:
                    self.directory_dirty = False
                    await self.account.directory_refresh()
            except Failure as error:
                if error.code == "storage_error":
                    self.storage_failed()
                elif self.state == "ready":
                    self.status("ready", "directory_sync_failed")
        self.directory_task = asyncio.create_task(refresh())

    def storage_failed(self):
        if self.retention_timer:
            self.retention_timer.cancel()
            self.retention_timer = None
        if self.store:
            self.store.healthy = False
        if self.transport:
            self.transport.abort("storage_error")
        self.status("failed", "storage_error")

    def schedule_cleanup(self):
        if self.retention_timer:
            self.retention_timer.cancel()
            self.retention_timer = None
        if not self.store or not self.store.healthy:
            return
        due = self.store.db.execute("""SELECT MIN(deadline) FROM (
            SELECT MIN(expires_at_ms) deadline FROM messages UNION ALL
            SELECT MIN(expires_at_ms) deadline FROM pending_events UNION ALL
            SELECT MIN(expires_at_ms) deadline FROM receipt_reports UNION ALL
            SELECT MIN(expires_at_ms) deadline FROM read_markers UNION ALL
            SELECT MIN(expires_at_ms) deadline FROM message_versions UNION ALL
            SELECT MIN(expires_at_ms) deadline FROM message_reactions UNION ALL
            SELECT MIN(expires_at_ms) deadline FROM interaction_outbox WHERE payload!='{}')""").fetchone()[0]
        if due is not None:
            self.retention_timer = signal_retention.Deadline(due, self.expire)

    def expire(self):
        self.retention_timer = None
        try:
            with self.store.transaction():
                self.store.cleanup()
            self.schedule_cleanup()
        except (sqlite3.Error, Failure):
            self.storage_failed()

    def domain_request(self, method, params):
        if not self.store or not self.store.healthy:
            raise Failure("storage_error")
        if not self.account_id:
            raise Failure("account_unlinked")
        if params.get("accountId", self.account_id) != self.account_id:
            raise Failure("account_mismatch")
        account = self.account_id
        with self.store.transaction():
            self.store.cleanup()
        if method == "conversations.page":
            return self.store.page(account, params)
        if method == "messages.page":
            return self.store.page(account, params, messages=True)
        if method == "message.get":
            return self.store.message(account, params.get("messageId"))
        if method == "conversation.get":
            return self.store.conversation_item(account, params.get("conversationId"))
        if method == "conversation.open":
            return self.store.open_conversation(account, params)
        if method == "draft.get":
            return self.store.draft(account, params.get("conversationId"))
        if method == "draft.set":
            return self.store.set_draft(account, params)
        if method == "reply.draft.get":
            return signal_replies.draft(self.store, account, params.get("conversationId"))
        if method == "reply.draft.set":
            return signal_replies.set_draft(self.store, account, params)
        if method == "conversation.preferences":
            return signal_directory.preferences(self.store, account, params)
        if method == "conversation.notifications":
            return signal_replies.configure(self.store, account, params)
        if method == "messages.read":
            if self.account_state != "linked" or self.state not in ("ready", "reconnecting"):
                raise Failure("account_unlinked")
            result = signal_receipts.mark_visible(self.store, account, params)
            self.wake_outbox.set()
            self.schedule_cleanup()
            return result
        if method == "message.delete" and params.get("scope") == "local":
            return signal_retention.local_delete(self.store, account, params)
        if method in ("message.send", "message.edit", "message.react", "message.delete", "operation.retry"):
            if self.account_state != "linked" or self.state not in ("ready", "reconnecting"):
                raise Failure("account_unlinked")
        if method == "message.send":
            if not self.store.conversation_item(account, params.get("conversationId"))["canSend"]:
                raise Failure("send_unavailable")
            result = self.outbox.enqueue(account, params)
        elif method in ("message.edit", "message.react", "message.delete"):
            if method == "message.delete" and params.get("scope") != "everyone":
                raise Failure("invalid_request")
            result = self.outbox.mutations.enqueue(account, params, {"message.edit": "edit", "message.react": "reaction", "message.delete": "delete"}[method])
        elif method == "operation.status":
            return self.outbox.status(account, params.get("operationId"))
        elif method == "operation.cancel":
            return self.outbox.cancel(account, params.get("operationId"))
        elif method == "operation.retry":
            result = self.outbox.retry(account, params.get("operationId"))
        else:
            raise Failure("unsupported_method")
        self.wake_outbox.set()
        self.schedule_cleanup()
        return result

    async def resolve_recipient(self, params):
        account = params.get("accountId")
        if not account or account != self.account_id:
            raise Failure("account_mismatch")
        if self.state != "ready" or self.account_state != "linked" or not self.transport:
            raise Failure("not_ready")
        query = text(params.get("query"), 128, empty=False).strip()
        if re.fullmatch(r"\+[1-9][0-9]{6,14}", query):
            field = "recipient"
        elif re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{2,31}\.[0-9]{2,9}", query):
            field = "username"
        else:
            raise Failure("invalid_recipient")
        address = self.store.account(account)["cli_address"]
        values = await self.transport.request("getUserStatus", {"account": address, field: [query]})
        if account != self.account_id:
            raise Failure("account_mismatch")
        matches = [v for v in values if isinstance(v, dict) and v.get("recipient") == query] if isinstance(values, list) else []
        if len(matches) != 1 or matches[0].get("isRegistered") is not True or not matches[0].get("uuid"):
            raise Failure("recipient_unresolved")
        sid = service_id(matches[0]["uuid"])
        if not sid.startswith("aci:"):
            raise Failure("recipient_unresolved")
        with self.store.transaction():
            existed = self.store.db.execute("SELECT 1 FROM conversations WHERE account_id=? AND target=?", (account, sid)).fetchone()
            cid = self.store.route(account, {"peer": sid, "number": query if field == "recipient" else None, "title": query})
            if not existed:
                self.store.db.execute('INSERT INTO conversation_preferences(conversation_id,initiated) VALUES(?,1)', (cid,))
        return self.store.conversation_item(account, cid)

    async def check_send_retention(self, account, operation):
        await self.account.check_current()
        row = self.outbox.row(account, operation)
        conversation = self.store.conversation(account, row["conversation_id"])
        address = self.store.account(account)["cli_address"]
        target = conversation["target"]
        await self.account.directory_refresh()
        if not self.store.conversation_item(account, row['conversation_id'])['canSend']:
            raise Failure('send_unavailable')
        if conversation["kind"] == "group":
            values = await self.transport.request("listGroups", {"account": address, "groupId": [target]})
            matches = [v for v in values if isinstance(v, dict) and v.get("id") == target] if isinstance(values, list) else []
        else:
            values = await self.transport.request("listContacts", {"account": address,
                "recipient": [target.removeprefix("aci:")], "allRecipients": True})
            matches = [v for v in values if isinstance(v, dict) and v.get("uuid") and service_id(v["uuid"]) == target] if isinstance(values, list) else []
        if len(matches) != 1 or "messageExpirationTime" not in matches[0]:
            raise Failure("retention_unverified")
        if matches[0].get("isBlocked") is True or matches[0].get("isTerminated") is True or (conversation["kind"] == "group" and
                (matches[0].get("isMember") is False or (matches[0].get("permissionSendMessage") == "ONLY_ADMINS"
                 and not any(v.get("uuid") == self.store.account(account)["service_id"].removeprefix("aci:") for v in matches[0].get("admins", []))))):
            raise Failure("send_unavailable")
        seconds = integer(matches[0]["messageExpirationTime"])
        with self.store.transaction():
            signal_retention.configure(self.store, account, row["conversation_id"], seconds, self.store.clock())

    async def set_expiration(self, params):
        async with self.mutation_lock:
            account = self.account_id
            if not account or params.get("accountId") != account:
                raise Failure("account_mismatch")
            if self.state != "ready" or not self.transport:
                raise Failure("not_ready")
            cid = params.get("conversationId")
            seconds = integer(params.get("seconds"))
            if seconds > signal_retention.MAX_EXPIRATION:
                raise Failure("invalid_request")
            conversation = self.store.conversation(account, cid)
            await self.account.check_current()
            if not self.store.conversation_item(account, cid)["canSetExpiration"]:
                raise Failure("send_unavailable")
            await self.account.directory_refresh()
            if not self.store.conversation_item(account, cid)["canSetExpiration"]:
                raise Failure("permission_denied")
            args = {"account": self.store.account(account)["cli_address"], "expiration": seconds}
            if conversation["kind"] == "group":
                # This command takes one ID; never omit it (that would create a group).
                args["groupId"] = conversation["target"]
                method = "updateGroup"
            else:
                args["recipient"] = conversation["target"].removeprefix("aci:")
                method = "updateContact"
            await self.transport.request(method, args, mutating=True)
            if account != self.account_id:
                raise Failure("account_mismatch")
            with self.store.transaction():
                signal_retention.configure(self.store, account, cid, seconds, self.store.clock())
            return self.store.conversation_item(account, cid)

    async def send_queued(self):
        account = self.account_id
        while True:
            await self.wake_outbox.wait()
            self.wake_outbox.clear()
            while self.transport and self.state == "ready" and not self.transport.uncertain_mutation:
                try:
                    batch = signal_receipts.next_batch(self.store, account)
                    operation = self.outbox.next(account)
                except sqlite3.Error:
                    self.storage_failed()
                    return
                if batch:
                    if not await self.send_read_batch(account, batch):
                        break
                    continue
                if not operation:
                    break
                began = False
                try:
                    async with self.mutation_lock:
                        await self.check_send_retention(account, operation)
                        params, attempt = self.outbox.begin(account, operation)
                        began = True
                        def settled(result, error, op=operation, number=attempt):
                            try:
                                self.outbox.finish(account, op, number, result, error)
                                self.schedule_cleanup()
                            except sqlite3.Error:
                                raise Failure("storage_error") from None
                            self.wake_outbox.set()
                        await self.transport.request(self.outbox.rpc_method(account, operation), params, mutating=True, on_result=settled, drop_payload=True)
                except asyncio.CancelledError:
                    raise
                except (Failure, sqlite3.Error) as error:
                    if asyncio.current_task().cancelling():
                        raise asyncio.CancelledError
                    code = error.code if isinstance(error, Failure) else "storage_error"
                    if code == "storage_error":
                        self.storage_failed()
                        return
                    if code == "operation_not_queued":
                        continue  # Cancelled/expired while the read preflight ran.
                    try:
                        self.outbox.fail(account, operation, code,
                                         definite=not began or code in ("busy", "transport_lost", "cancelled"))
                    except Failure:
                        self.storage_failed()
                        return
                    if self.transport.closed.done():
                        return
                    if code == "busy":
                        return

    async def send_read_batch(self, account, batch):
        async with self.mutation_lock:
            began = False
            try:
                await self.account.check_current()
                await self.account.directory_refresh()
                # A phone read may have cleared these keys while preflight awaited.
                batch = signal_receipts.next_batch(self.store, account)
                if not batch:
                    return True
                signal_receipts.batch_state(self.store, account, batch, "sending")
                began = True
                def settled(result, error):
                    signal_receipts.finish_batch(self.store, account, batch, result, error)
                    self.wake_outbox.set()
                await self.transport.request("sendReceipt", batch, mutating=True, on_result=settled)
                return True
            except asyncio.CancelledError:
                if began and self.store.healthy:
                    signal_receipts.batch_state(self.store, account, batch, "unknown")
                raise
            except (Failure, sqlite3.Error) as error:
                if asyncio.current_task().cancelling():
                    if began and self.store.healthy:
                        signal_receipts.batch_state(self.store, account, batch, "unknown")
                    raise asyncio.CancelledError
                code = error.code if isinstance(error, Failure) else "storage_error"
                if code == "storage_error":
                    self.storage_failed()
                elif began:
                    signal_receipts.batch_state(self.store, account, batch, "unknown")
                return False

    async def stop_sender(self):
        if self.media_task:
            self.media_task.cancel()
            await asyncio.gather(self.media_task, return_exceptions=True)
            self.media_task = None
        if self.directory_task:
            self.directory_task.cancel()
            await asyncio.gather(self.directory_task, return_exceptions=True)
            self.directory_task = None
        if self.sender:
            self.sender.cancel()
            await asyncio.gather(self.sender, return_exceptions=True)
            self.sender = None

    async def settle_requests(self):
        tasks = list(self.requests.values())
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        self.requests.clear()

    async def serve_request(self, value):
        request_id = value["id"]
        try:
            method, params = value["method"], value.get("params", {})
            if method == "service.status":
                result = self.snapshot()
            elif self.args.test_scenario and method == "test.metrics":
                # Explicit fixture mode only; never export content or account keys.
                result = {"retentionTimers": int(self.retention_timer is not None),
                          "typingTimers": int(self.typing.timer is not None),
                          "rpcPending": len(self.transport.pending) if self.transport else 0,
                          "lateResults": len(self.transport.results) if self.transport else 0,
                          "outputBytes": len(self.output.buffer),
                          "mediaWorker": bool(self.media_task and not self.media_task.done()),
                          "directoryWorker": bool(self.directory_task and not self.directory_task.done())}
            elif method == "service.retry":
                if self.state not in ("failed", "idle") or self.account.attempt:
                    raise Failure("busy")
                self.retry.set()
                result = {"accepted": True}
            elif method == "request.cancel":
                target = params.get("id")
                task = self.requests.get(target) if isinstance(target, str) else None
                if task and target != request_id:
                    task.cancel()
                result = {"accepted": bool(task) and target != request_id}
            elif method == "conversation.expiration":
                result = await self.set_expiration(params)
            elif method == "typing.set":
                result = await self.typing.set(params)
            elif method in GROUP_CAPABILITIES:
                result = await self.groups.request(method, params)
            elif method == "recipient.resolve":
                result = await self.resolve_recipient(params)
            elif method.startswith("attachment."):
                result = await self.media_request(method, params)
            elif method in CAPABILITIES:
                result = self.domain_request(method, params)
            elif method in ACCOUNT_CAPABILITIES:
                result = await self.account.request(method, params)
            elif self.args.test_scenario and method in ("test.echo", "test.mutate"):
                if not self.transport or self.state != "ready":
                    raise Failure("not_ready")
                result = await self.transport.request(method[5:], params, mutating=method == "test.mutate")
            else:
                raise Failure("unsupported_method")
            self.emit("response", id=request_id, result=result)
        except asyncio.CancelledError:
            self.respond_error(request_id, "cancelled")
        except Failure as error:
            if error.code == "storage_error":
                self.storage_failed()
            self.respond_error(request_id, error.code)
        except sqlite3.Error:
            self.storage_failed()
            self.respond_error(request_id, "storage_error")
        except OSError:
            self.respond_error(request_id, "storage_error")
        finally:
            self.requests.pop(request_id, None)

    def respond_error(self, request_id, code):
        self.emit("response", id=request_id, error={"code": code, "retryable": code in ("busy", "not_ready")})

    async def input(self):
        reader = asyncio.StreamReader(limit=MAX_FRAME)
        pipe, _ = await asyncio.get_running_loop().connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin.buffer)
        try:
            while not self.stop.is_set():
                value = await frame(reader)
                request_id = value.get("id")
                if (value.get("type") != "request" or not isinstance(request_id, str)
                        or not request_id or len(request_id) > 128 or not isinstance(value.get("method"), str)
                        or not isinstance(value.get("params", {}), dict)):
                    raise Failure("invalid_request")
                if value.get("v") != 1:
                    self.respond_error(request_id, "unsupported_version")
                elif value.get("generation") != self.generation:
                    self.respond_error(request_id, "stale_generation")
                elif request_id in self.requests:
                    # Duplicate IDs make correlation ambiguous: end the session.
                    raise Failure("invalid_request")
                elif len(self.requests) >= 32:
                    self.respond_error(request_id, "busy")
                else:
                    self.requests[request_id] = asyncio.create_task(self.serve_request(value))
                value = None
        except Failure as error:
            if error.code != "transport_lost":
                self.status("failed", error.code)
            self.stop.set()
        finally:
            pipe.close()
            self.stop.set()

    async def supervise(self):
        lease = None
        try:
            lease = StoreLease()
            # One bounded acquisition wait supports overlapping QML reload graphs.
            for attempt in range(7):
                if lease.acquire():
                    break
                if attempt == 6:
                    raise Failure("busy")
                self.status("reconnecting", "busy")
                await asyncio.sleep(1)
            if not self.args.test_scenario:
                from signal_release import claim_release
                claim_release(lease)
            self.store = Store(lease, self.event)
            self.lease = lease
            self.outbox = Outbox(self.store, require_timer=not self.args.test_scenario)
            self.account_id = self.store.active_account()
            if self.account_id:
                self.account_state = "linked"
            self.schedule_cleanup()
            while True:
                try:
                    config = lease.read_config()
                    self.account.config = {**DEFAULT_CONFIG, **(config or {})}
                    if self.args.test_scenario and (config is None or config["enabled"]):
                        command = [sys.executable, "-B", str(Path(__file__).resolve().parents[1] / "tests/signal_cli_fake.py"),
                                   "--lifecycle-scenario", self.args.test_scenario]
                        env = dict(os.environ)
                    elif config is None or not config["enabled"]:
                        self.status("idle" if config is None else "disabled")
                        await self.retry.wait()
                        self.retry.clear()
                        return
                    else:
                        from signal_release import command as release_command
                        command, env = await self.media_worker(release_command, config)
                    self.status("starting")
                    await version(command, lease.lock_fd, env)
                    if not self.args.test_scenario:
                        from signal_media import verify_cli
                        await self.media_worker(verify_cli, command[0])
                    self.cli_version = "0.14.8"
                    cli_dir = lease.data / "cli"
                    os.close(directory(cli_dir, private=True))
                    os.close(directory(cli_dir / "tmp", private=True))
                    env["JAVA_OPTS"] = "-Djava.io.tmpdir=" + str(cli_dir / "tmp")
                    child = await spawn([*command, "--data-dir", str(cli_dir), "--scrub-log", "--disable-send-log", "jsonRpc",
                                         "--receive-mode", "manual", "--ignore-stories", "--ignore-stickers",
                                         "--ignore-avatars"], lease.lock_fd, env)
                    self.transport = RpcTransport(child, self.incoming, self.generation)
                    accounts = await self.account.accounts()
                    if not accounts and self.account.attempt:
                        await self.account.pair()
                        accounts = await self.account.accounts()
                    elif accounts and self.account.attempt:
                        self.account.clear_attempt()
                    was_reconciling = self.account.reconciling
                    self.account.reconciling = False
                    self.account_state = "linked" if accounts else ("relinkRequired" if self.account_id else "unlinked")
                    if not accounts:
                        await self.transport.close()
                        self.transport = None
                        self.status("idle", "relink_required" if self.account_id else self.account.link_error)
                        await self.retry.wait()
                        self.retry.clear()
                        return
                    address = accounts[0]["number"]
                    identity = await self.transport.request("listContacts", {"account": address, "recipient": [address], "allRecipients": True})
                    matches = [v for v in identity if isinstance(v, dict) and v.get("number") == address and v.get("uuid")] if isinstance(identity, list) else []
                    if len(matches) != 1:
                        raise Failure("account_identity_unknown")
                    self.account_id = self.store.bind_account(matches[0]["uuid"], address)
                    self.account.link_error = ""
                    subscription = await self.transport.request("subscribeReceive", {"account": accounts[0]["number"]})
                    if type(subscription) is not int:
                        raise Failure("invalid_frame")
                    # Ask only after provisioning; ordinary restarts read the CLI's cache.
                    if was_reconciling:
                        try:
                            await self.transport.request("sendSyncRequest", {"account": address}, mutating=True)
                        except Failure:
                            self.account.link_error = "directory_sync_failed"
                    await self.account.directory_refresh()
                    self.status("ready", self.account.link_error)
                    self.wake_outbox.set()
                    self.sender = asyncio.create_task(self.send_queued())
                    self.import_media()
                    started = asyncio.get_running_loop().time()
                    code = await self.transport.closed
                    if asyncio.get_running_loop().time() - started >= 60:
                        self.attempts = 0
                    raise Failure(code)
                except Failure as error:
                    if asyncio.current_task().cancelling():
                        raise asyncio.CancelledError
                    await self.stop_sender()
                    await self.settle_requests()
                    if self.transport:
                        await self.transport.close()
                        self.transport = None
                    if error.code == "link_reconcile":
                        self.status("starting")
                        continue
                    self.account.clear_attempt(self.account.link_error or (error.code if self.account.attempt else ""))
                    if error.code == "storage_error" or not self.store.healthy:
                        raise Failure("storage_error")
                    if error.code in FATAL or self.attempts >= len(BACKOFF):
                        self.account.reconciling = False
                        self.status("failed", error.code)
                        await self.retry.wait()
                        self.retry.clear()
                        self.attempts = 0
                    else:
                        delay = BACKOFF[self.attempts]
                        self.attempts += 1
                        self.status("reconnecting", error.code)
                        await asyncio.sleep(delay)
                    self.generation = uuid.uuid4().hex
                    self.sequence = 0
                    self.emit("hello", data=self.snapshot())
        except (Failure, OSError) as error:
            self.status("failed", error.code if isinstance(error, Failure) else "storage_error")
            await self.retry.wait()
            self.retry.clear()
        finally:
            self.typing.clear()
            self.lease = None
            if self.retention_timer:
                self.retention_timer.cancel()
                self.retention_timer = None
            await self.stop_sender()
            await self.settle_requests()
            if self.transport:
                await self.transport.close()
                self.transport = None
            if self.store:
                try:
                    self.store.close()
                except sqlite3.Error:
                    self.status("failed", "storage_error")
                self.store, self.outbox = None, None
                self.account_id = ""
            if lease:
                lease.close()

    async def manage(self):
        while not self.stop.is_set():
            supervisor = asyncio.create_task(self.supervise())
            restart = asyncio.create_task(self.restart.wait())
            try:
                await asyncio.wait((supervisor, restart), return_when=asyncio.FIRST_COMPLETED)
            finally:
                supervisor.cancel()
                restart.cancel()
                await asyncio.gather(supervisor, restart, return_exceptions=True)
            if not supervisor.cancelled() and supervisor.exception():
                # No traceback may expose upstream values. Unexpected failures are finite.
                self.status("failed", "internal_error")
                await self.retry.wait()
            self.restart.clear()
            self.retry.clear()
            self.attempts = 0
            self.generation = uuid.uuid4().hex
            self.sequence = 0
            if not self.stop.is_set():
                self.emit("hello", data=self.snapshot())

    async def run(self):
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(sig, self.stop.set)
        parent_death(self.args.owner_pid or os.getppid(), signal.SIGTERM)
        self.emit("hello", data=self.snapshot())
        reader = asyncio.create_task(self.input())
        supervisor = asyncio.create_task(self.manage())
        await self.stop.wait()
        self.status("stopping", self.error)
        reader.cancel()
        supervisor.cancel()
        await asyncio.gather(reader, supervisor, return_exceptions=True)
        self.output.flush()
        loop.remove_writer(self.output.fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner-pid", type=int)
    parser.add_argument("--test-scenario", help="Explicit synthetic peer; never selected from production config")
    args = parser.parse_args()
    os.umask(0o077)
    async def run():
        await Bridge(args).run()
    try:
        asyncio.run(run())
    except (OSError, Failure):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
