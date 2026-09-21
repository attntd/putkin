"""Linked-device policy. A pairing attempt belongs to the bridge, never a view."""
import asyncio
import json
from pathlib import Path
import time
import uuid

from signal_events import group_id, service_id, text
from signal_qr import library, modules
from signal_transport import Failure
import signal_directory

CAPABILITIES = ["account.configure", "account.link.start", "account.link.cancel",
                "account.refresh", "account.directory", "account.history.clear"]
LINK_SECONDS = 120
DEFAULT_CONFIG = {"v": 1, "enabled": False, "deviceName": "Putkin", "typingIndicators": False}


class Account:
    def __init__(self, bridge):
        self.bridge = bridge
        self.config = dict(DEFAULT_CONFIG)
        self.attempt = ""
        self.link_error = ""
        self.reconciling = False
        self.directory_lock = asyncio.Lock()

    def snapshot(self):
        return {"configuration": self.config, "linkAttempt": self.attempt,
                "linkError": self.link_error, "reconciling": self.reconciling}

    def configure(self, params):
        if set(params) - {"enabled", "executable", "javaHome", "deviceName", "typingIndicators"}:
            raise Failure("invalid_config")
        config = {**self.config, **params, "v": 1}
        if type(config["enabled"]) is not bool or type(config["typingIndicators"]) is not bool:
            raise Failure("invalid_config")
        for key, limit in (("executable", 4096), ("javaHome", 4096), ("deviceName", 128)):
            if key not in config:
                continue
            value = text(config[key], limit).strip()
            if any(ord(c) < 32 for c in value):
                raise Failure("invalid_config")
            if key == "deviceName" and not value:
                raise Failure("invalid_config")
            if key == "javaHome" and value and not Path(value).is_absolute():
                raise Failure("invalid_config")
            if key == "executable" and "/" in value and not Path(value).is_absolute():
                raise Failure("invalid_config")
            if value:
                config[key] = value
            else:
                config.pop(key, None)
        self.bridge.lease.write_config(config)
        self.config = config

    def clear_attempt(self, code=""):
        attempt, self.attempt = self.attempt, ""
        self.link_error = code
        if attempt:
            self.bridge.event("account.link.cleared", {"attemptId": attempt})
        if self.bridge.account_state == "linking":
            self.bridge.account_state = "unlinked"

    async def request(self, method, params):
        b = self.bridge
        if not b.lease or not b.store or not b.store.healthy:
            raise Failure("not_ready")
        if method == "account.configure":
            if self.attempt:
                raise Failure("busy")
            self.configure(params)
            await b.typing.stop_all()
            b.restart.set()
            return {"accepted": True}
        if method == "account.link.start":
            if self.attempt:
                return {"attemptId": self.attempt}
            if self.reconciling or b.state not in ("idle", "disabled", "failed"):
                raise Failure("busy")
            if b.account_state == "linked":
                raise Failure("already_linked")
            library()  # Fail before requesting a provisioning secret.
            self.configure({"enabled": True, "deviceName": params.get("deviceName", self.config["deviceName"])})
            self.attempt, self.link_error = uuid.uuid4().hex, ""
            b.account_state = "linking"
            b.status("starting")
            b.restart.set()
            return {"attemptId": self.attempt}
        if method == "account.link.cancel":
            if self.attempt and params.get("attemptId") != self.attempt:
                raise Failure("stale_attempt")
            if self.attempt:
                self.clear_attempt("cancelled")
                self.reconciling = True
                b.restart.set()  # Reap the old CLI before checking listAccounts.
                b.status("starting")
            return {"accepted": True}
        if method == "account.refresh":
            if b.transport and b.state == "ready":
                await self.check_current()
                await self.directory_refresh()
            elif b.state in ("idle", "failed"):
                b.restart.set()
            return {"accepted": True}
        if method == "account.directory":
            row = b.store.db.execute("SELECT value FROM store_metadata WHERE key=?",
                                     ("directory:" + b.account_id,)).fetchone()
            return json.loads(row[0]) if row else {"contacts": [], "groups": []}
        if method == "account.history.clear":
            if b.state != "disabled" or b.transport or self.attempt:
                raise Failure("not_disabled")
            if params.get("confirm") != "delete-local-history" or params.get("accountId") != b.account_id:
                raise Failure("confirmation_required")
            with b.store.transaction():
                for table in ("directory_operations", "directory_avatars", "conversation_preferences", "version_recipients", "interaction_outbox", "message_reactions", "message_versions", "message_metadata", "read_queue", "read_markers", "receipt_reports", "message_recipients", "reply_drafts", "conversation_notifications", "outbox_results", "outbox_attempts", "outbox", "drafts", "attachment_refs",
                              "attachments", "pending_events", "tombstones", "messages", "conversations",
                              "recipient_aliases", "recipients"):
                    b.store.db.execute("DELETE FROM " + table)
                b.store.db.execute("DELETE FROM store_metadata WHERE key LIKE 'directory:%'")
                b.store.purged = True
                b.store.changed("history.cleared", accountId=b.account_id)
            b.schedule_cleanup()
            signal_directory.cleanup_avatars(b.store)
            return {"cleared": True}
        raise Failure("unsupported_method")

    async def accounts(self):
        result = await self.bridge.transport.request("listAccounts")
        if not isinstance(result, list) or any(not isinstance(v, dict) or not isinstance(v.get("number"), str) for v in result):
            raise Failure("invalid_frame")
        if len(result) > 1:
            raise Failure("multiple_accounts")
        return result

    async def check_current(self):
        b = self.bridge
        accounts = await self.accounts()
        address = b.store.account(b.account_id)["cli_address"]
        if not accounts or accounts[0]["number"] != address:
            b.account_state = "relinkRequired"
            b.transport.abort("relink_required")
            b.status("failed", "relink_required")
            raise Failure("relink_required")

    async def pair(self):
        b, attempt = self.bridge, self.attempt
        uri = None
        expires = int(time.time() * 1000) + LINK_SECONDS * 1000
        try:
            # One deadline includes allocation of the URI and waiting for the phone.
            async with asyncio.timeout(LINK_SECONDS):
                result = await b.transport.request("startLink", mutating=True, timeout=20)
                uri = result.get("deviceLinkUri") if isinstance(result, dict) else None
                qr = modules(uri)
                b.account_state = "linking"
                b.status("idle")
                b.event("account.link.qr", {"attemptId": attempt, "modules": qr,
                        "expiresAtMs": expires})
                await b.transport.request("finishLink", {"deviceLinkUri": uri,
                        "deviceName": self.config["deviceName"]}, mutating=True, timeout=LINK_SECONDS)
        except (Failure, TimeoutError) as error:
            if asyncio.current_task().cancelling():
                self.reconciling = True
                raise asyncio.CancelledError
            self.clear_attempt("link_expired" if isinstance(error, TimeoutError) or error.code in ("timeout", "result_unknown") else error.code)
            self.reconciling = True
            raise Failure("link_reconcile") from None
        finally:
            uri = None
            self.clear_attempt(self.link_error)
        self.reconciling = True
        # Success also reconciles through listAccounts + identity, never an RPC number alone.

    async def directory_refresh(self):
        async with self.directory_lock:
            return await self.read_directory()

    async def read_directory(self):
        b = self.bridge
        account = b.account_id
        address = b.store.account(account)["cli_address"]
        contacts = await b.transport.request("listContacts", {"account": address, "allRecipients": True})
        groups = await b.transport.request("listGroups", {"account": address, "detailed": True})
        result = signal_directory.normalize(contacts, groups, b.store.account(account)["service_id"])
        return signal_directory.install(b.store, account, result)
