"""Event-driven logind/ScreenSaver bridge for the lock in our Quickshell process.

The private stdin pipe carries compositor lock state, never credentials. No
external locker, Wayland idle daemon, shell commands or polling are used here.
"""
import json
import os
import pwd
import re
import sys
import time

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

LOGIN = "org.freedesktop.login1"
MANAGER = LOGIN + ".Manager"
SESSION = LOGIN + ".Session"
LOGIN_PATH = "/org/freedesktop/login1"
SAVER = "org.freedesktop.ScreenSaver"
SAVER_PATH = "/org/freedesktop/ScreenSaver"
PROPERTIES = "org.freedesktop.DBus.Properties"
FPRINT = "net.reactivated.Fprint"


class ScreenSaver(dbus.service.Object):
    def __init__(self, backend, path):
        super().__init__(backend.session, path)
        self.backend = backend

    @dbus.service.method(SAVER, in_signature="", out_signature="")
    def Lock(self):
        self.backend.ask_lock("external")

    @dbus.service.method(SAVER, in_signature="b", out_signature="b")
    def SetActive(self, active):
        if active:
            self.backend.ask_lock("external")
        # D-Bus does not provide an authentication bypass.
        return bool(active)

    @dbus.service.method(SAVER, in_signature="", out_signature="b")
    def GetActive(self):
        return self.backend.secure

    @dbus.service.method(SAVER, in_signature="", out_signature="u")
    def GetActiveTime(self):
        return int(time.monotonic() - self.backend.locked_at) if self.backend.secure else 0

    @dbus.service.method(SAVER, in_signature="ss", out_signature="u", sender_keyword="sender")
    def Inhibit(self, application, reason, sender=None):
        self.backend.cookie += 1
        cookie = self.backend.cookie
        self.backend.inhibitors[cookie] = str(sender)
        self.backend.publish()
        return cookie

    @dbus.service.method(SAVER, in_signature="u", out_signature="", sender_keyword="sender")
    def UnInhibit(self, cookie, sender=None):
        if self.backend.inhibitors.get(int(cookie)) == str(sender):
            del self.backend.inhibitors[int(cookie)]
            self.backend.publish()

    @dbus.service.signal(SAVER, signature="b")
    def ActiveChanged(self, active):
        pass


class SessionBackend:
    lock_timeout_ms = 7000
    action_timeout = 8

    def __init__(self, emit):
        self.emit = emit
        self.system = dbus.SystemBus()
        self.session = dbus.SessionBus()
        self.login_owner = ""
        self.session_id = self.session_path = ""
        self.pending = None
        self.timer = 0
        self.sleeping = False
        self.last_id = 0
        self.token = 0
        self.native = self.locked = self.secure = False
        self.locked_at = 0
        self.delay_fd = None
        self.idle_hint = False
        self.idle_blocked = self.sleep_blocked = False
        self.fingerprint = False
        self.cookie = 0
        self.inhibitors = {}
        self.owns_saver = False
        self.error = ""
        self.capabilities = {}
        self.savers = [ScreenSaver(self, path) for path in (SAVER_PATH, "/ScreenSaver")]
        self.matches = [
            self.system.add_signal_receiver(self.owner_changed, "NameOwnerChanged", "org.freedesktop.DBus",
                bus_name="org.freedesktop.DBus", path="/org/freedesktop/DBus"),
            self.session.add_signal_receiver(self.session_owner_changed, "NameOwnerChanged", "org.freedesktop.DBus",
                bus_name="org.freedesktop.DBus", path="/org/freedesktop/DBus"),
            self.system.add_signal_receiver(self.prepare_sleep, "PrepareForSleep", MANAGER,
                path=LOGIN_PATH, sender_keyword="sender"),
            self.system.add_signal_receiver(self.session_lock, "Lock", SESSION,
                sender_keyword="sender", path_keyword="path"),
            self.system.add_signal_receiver(self.properties_changed, "PropertiesChanged", PROPERTIES,
                path=LOGIN_PATH, sender_keyword="sender")]
        self.refresh()

    @staticmethod
    def method(bus, owner, path, interface, name):
        return bus.get_object(owner, path, introspect=False).get_dbus_method(name, interface)

    def login(self, name, *args, **kwargs):
        return self.method(self.system, self.login_owner, LOGIN_PATH, MANAGER, name)(*args, **kwargs)

    def current_session(self):
        identifier = os.environ.get("XDG_SESSION_ID", "")
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", identifier):
            raise RuntimeError("Brak jednoznacznego XDG_SESSION_ID.")
        path = str(self.login("GetSession", dbus.String(identifier), timeout=1))
        values = self.method(self.system, self.login_owner, path, PROPERTIES, "GetAll")(SESSION, timeout=1)
        if (str(values.get("Id")) != identifier or int(values.get("User", [-1])[0]) != os.getuid()
                or not values.get("Active") or values.get("Remote") or values.get("Class") != "user"
                or values.get("Type") not in ("wayland", "tty")):
            raise RuntimeError("Nie potwierdzono własnej, aktywnej sesji lokalnej.")
        if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or not os.environ.get("WAYLAND_DISPLAY"):
            raise RuntimeError("Nie rozpoznano środowiska sesji Hyprlanda.")
        return identifier, path

    def acquire_delay(self):
        if self.delay_fd is None and self.session_id and not self.sleeping:
            fd = self.login("Inhibit", "sleep", "Putkin", "Blokada przed uśpieniem", "delay", timeout=1).take()
            os.set_inheritable(fd, False)
            self.delay_fd = fd

    def release_delay(self):
        if self.delay_fd is not None:
            os.close(self.delay_fd)
            self.delay_fd = None

    def refresh(self):
        if self.pending:
            return
        caps = {}
        self.error = ""
        self.session_id = self.session_path = ""
        try:
            owner = str(self.system.get_name_owner(LOGIN))
            if owner != self.login_owner:
                self.release_delay()
            self.login_owner = owner
            for action, method in [("reboot", "CanReboot"), ("poweroff", "CanPowerOff"), ("suspend", "CanSuspend"),
                                   ("idleSuspend", "CanSuspendThenHibernate")]:
                value = str(self.login(method, timeout=1))
                caps[action] = {"available": value in ("yes", "challenge"), "reason":
                    "Wymaga autoryzacji systemowej." if value == "challenge" else "" if value == "yes"
                    else "Brak uprawnień." if value == "no"
                    else "Operację wstrzymuje inhibitor aplikacji." if value in ("inhibited", "inhibitor-blocked", "challenge-inhibitor-blocked")
                    else "Operacja nieobsługiwana przez logind."}
            try:
                self.session_id, self.session_path = self.current_session()
                self.acquire_delay()
                caps["logout"] = {"available": True, "reason": ""}
            except (dbus.DBusException, RuntimeError, OSError) as error:
                self.error = str(error)
                self.release_delay()
                caps["logout"] = {"available": False, "reason": self.error}
            self.read_inhibitors()
        except dbus.DBusException:
            self.login_owner = ""
            self.release_delay()
            for action in ("logout", "reboot", "poweroff", "suspend", "idleSuspend"):
                caps[action] = {"available": False, "reason": "Logind niedostępny lub nie odpowiada."}
        if not self.owns_saver:
            result = self.session.request_name(SAVER, dbus.bus.NAME_FLAG_DO_NOT_QUEUE)
            self.owns_saver = result in (dbus.bus.REQUEST_NAME_REPLY_PRIMARY_OWNER, dbus.bus.REQUEST_NAME_REPLY_ALREADY_OWNER)
        if not self.owns_saver:
            self.error = "Inny program obsługuje bezczynność (org.freedesktop.ScreenSaver)."
        try:
            owner = FPRINT
            path = self.method(self.system, owner, "/net/reactivated/Fprint/Manager", FPRINT + ".Manager", "GetDefaultDevice")(timeout=1)
            fingers = self.method(self.system, owner, str(path), FPRINT + ".Device", "ListEnrolledFingers")(pwd.getpwuid(os.getuid()).pw_name, timeout=1)
            self.fingerprint = bool(fingers)
        except dbus.DBusException:
            self.fingerprint = False
        caps["lock"] = {"available": self.native, "reason": "" if self.native else "Blokada Quickshell nie jest gotowa."}
        if not self.native or not self.session_id or (self.delay_fd is None and not self.sleeping):
            caps["suspend"] = {"available": False, "reason": self.error or "Brak gotowości blokady przed snem."}
            caps["idleSuspend"] = dict(caps["suspend"])
        self.capabilities = caps
        self.publish()

    def publish(self):
        self.emit({"state": self.capabilities, "session": self.session_id, "confirmation": self.native,
            "idleReady": self.owns_saver and bool(self.session_id),
            "idleInhibited": self.idle_blocked or bool(self.inhibitors), "sleepInhibited": self.sleep_blocked,
            "fingerprint": self.fingerprint, "error": self.error})

    def read_inhibitors(self):
        try:
            flags = str(self.method(self.system, self.login_owner, LOGIN_PATH, PROPERTIES, "Get")(MANAGER, "BlockInhibited", timeout=1)).split(":")
            self.idle_blocked, self.sleep_blocked = "idle" in flags, "sleep" in flags
        except dbus.DBusException:
            # Unknown inhibitor state must not trigger an automatic action.
            self.idle_blocked = self.sleep_blocked = True

    def properties_changed(self, interface, values, invalidated, sender=None):
        if str(sender) != self.login_owner or interface != MANAGER:
            return
        if "BlockInhibited" in values or "BlockInhibited" in invalidated:
            self.read_inhibitors()
            # Can* changes with inhibition in systemd 261. Refresh availability
            # on release too, so automatic sleep can resume without opening UI.
            if self.pending:
                self.publish()
            else:
                self.refresh()

    def owner_changed(self, name, old, new):
        if name == LOGIN:
            self.release_delay()
            self.sleeping = False
            self.emit({"hold": False})
            if self.pending:
                self.finish(False, "Usługa sesji zniknęła; operacja przerwana.")
            self.refresh()
        elif name == FPRINT:
            if new:
                self.refresh()
            else:
                # fprintd normally exits when unused. Do not reactivate it on
                # every idle exit; the next session request refreshes detection.
                self.fingerprint = False
                self.publish()

    def session_owner_changed(self, name, old, new):
        if not new:
            remaining = {cookie: owner for cookie, owner in self.inhibitors.items() if owner != str(name)}
            if remaining != self.inhibitors:
                self.inhibitors = remaining
                self.publish()
        if name == SAVER and not new:
            self.owns_saver = False
            self.refresh()

    def session_lock(self, sender=None, path=None):
        if str(sender) == self.login_owner and str(path) == self.session_path:
            self.ask_lock("external")

    def hint(self, name, value):
        if self.login_owner and self.session_path:
            try:
                self.method(self.system, self.login_owner, self.session_path, SESSION, name)(dbus.Boolean(value), timeout=1)
            except dbus.DBusException:
                self.error = "Logind nie przyjął stanu sesji."
                self.publish()

    def prepare_sleep(self, sleeping, sender=None):
        if str(sender) != self.login_owner or not self.login_owner:
            return
        if sleeping and not self.sleeping:
            self.sleeping = True
            self.emit({"hold": True})
            self.ask_lock("sleep")
            if self.secure:
                self.release_delay()
        elif not sleeping and self.sleeping:
            self.sleeping = False
            self.emit({"hold": False})
            self.refresh()
            self.emit({"resumed": True})

    def ask_lock(self, reason):
        self.token += 1
        if reason in ("sleep", "suspend", "idleSuspend"):
            self.emit({"hold": True})
        if self.pending and self.pending["phase"] == "locking":
            self.pending["token"] = self.token
        self.emit({"lockRequest": self.token, "reason": reason})

    def native_state(self, value):
        if (type(value.get("locked")) is not bool or type(value.get("secure")) is not bool
                or type(value.get("token")) is not int or value["token"] != self.token
                or (value["secure"] and not value["locked"])):
            return
        first = not self.native
        self.native = True
        self.locked = value["locked"]
        changed = self.secure != value["secure"]
        self.secure = value["secure"]
        if changed:
            self.locked_at = time.monotonic() if self.secure else 0
            self.hint("SetLockedHint", self.secure)
            for saver in self.savers:
                saver.ActiveChanged(self.secure)
        if self.sleeping and self.secure:
            self.release_delay()
        if self.pending and self.pending["phase"] == "locking" and self.pending.get("token") == self.token and self.secure:
            self.confirm_lock(self.pending["id"])
        if first:
            self.refresh()

    def finish(self, success, message=""):
        if not self.pending:
            return
        identifier = self.pending["id"]
        self.pending = None
        if self.timer:
            GLib.source_remove(self.timer)
            self.timer = 0
        if not self.sleeping:
            self.emit({"hold": False})
        self.emit({"completed": identifier, "success": success, "message": message})

    def expired(self):
        self.timer = 0
        self.finish(False, "Nie potwierdzono blokady w terminie. Uśpienie nie zostało wysłane.")
        return False

    def request(self, identifier, action):
        if self.pending or identifier <= self.last_id or action not in ("lock", "logout", "reboot", "poweroff", "suspend", "idleSuspend"):
            self.emit({"completed": identifier, "success": False, "message": "Odrzucono powtórzone lub nieprawidłowe żądanie."})
            return
        self.last_id = identifier
        self.refresh()
        self.pending = {"id": identifier, "action": action, "phase": "action"}
        capability = self.capabilities[action]
        if not capability["available"]:
            self.finish(False, capability["reason"])
        elif action in ("lock", "suspend", "idleSuspend"):
            self.pending.update(phase="locking", deadline=time.monotonic() + self.lock_timeout_ms / 1000)
            self.timer = GLib.timeout_add(self.lock_timeout_ms, self.expired)
            self.emit({"progress": identifier, "phase": "locking"})
            self.ask_lock(action)
        else:
            self.perform(identifier)

    def confirm_lock(self, identifier):
        if time.monotonic() >= self.pending["deadline"]:
            self.expired()
            return
        self.emit({"progress": identifier, "phase": "locked"})
        if self.pending["action"] == "lock":
            self.finish(True, "Blokada potwierdzona przez kompozytor.")
        else:
            self.pending["phase"] = "action"
            if self.timer:
                GLib.source_remove(self.timer)
                self.timer = 0
            self.perform(identifier)

    def perform(self, identifier):
        if not self.pending or self.pending["id"] != identifier:
            return
        action = self.pending["action"]
        try:
            if str(self.system.get_name_owner(LOGIN)) != self.login_owner:
                raise RuntimeError("Zmieniła się usługa logind.")
            if action in ("suspend", "idleSuspend") and (not self.secure or time.monotonic() >= self.pending["deadline"]):
                raise RuntimeError("Blokada nie jest już potwierdzona; odmowa uśpienia.")
            if action == "logout":
                session_id, _ = self.current_session()
                method, args = "TerminateSession", [dbus.String(session_id)]
            else:
                method = {"poweroff": "PowerOff", "reboot": "Reboot", "suspend": "Suspend", "idleSuspend": "SuspendThenHibernate"}[action]
                args = [dbus.Boolean(True)]
            self.emit({"progress": identifier, "phase": "dispatching"})
            def reply(*_args):
                if self.pending and self.pending["id"] == identifier:
                    self.finish(True, "Logind przyjął żądanie.")
            def error(value):
                if self.pending and self.pending["id"] == identifier:
                    name = value.get_dbus_name()
                    uncertain = name in ("org.freedesktop.DBus.Error.NoReply", "org.freedesktop.DBus.Error.Timeout")
                    self.finish(False, "Brak wyniku logind; operacja mogła zostać przyjęta. Nie ponowiono." if uncertain
                                else "Logind odrzucił operację: " + name)
            self.login(method, *args, timeout=self.action_timeout, reply_handler=reply, error_handler=error)
        except (dbus.DBusException, RuntimeError) as error:
            self.finish(False, str(error))

    def command(self, value):
        action = value.get("action")
        if action == "refresh":
            self.refresh()
        elif action == "lock-state":
            self.native_state(value)
        elif action == "idle-hint" and type(value.get("idle")) is bool:
            self.idle_hint = value["idle"]
            self.hint("SetIdleHint", self.idle_hint)
        elif type(value.get("id")) is int and 0 < value["id"] < 2147483647:
            if action == "cancel":
                if self.pending and self.pending["id"] == value["id"]:
                    self.finish(False, "Anulowano oczekiwanie. Wysłanej operacji systemowej nie można cofnąć.")
            else:
                self.request(value["id"], action)

    def close(self):
        self.release_delay()
        for saver in self.savers:
            saver.remove_from_connection()
        if self.owns_saver:
            self.session.release_name(SAVER)


def main(backend_class=SessionBackend):
    DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()
    backend = backend_class(lambda value: print(json.dumps(value, ensure_ascii=False), flush=True))
    buffer = bytearray()
    def input_ready(_fd, condition):
        if condition & (GLib.IO_HUP | GLib.IO_ERR):
            loop.quit()
            return False
        data = os.read(sys.stdin.fileno(), 4096)
        if not data:
            loop.quit()
            return False
        buffer.extend(data)
        if len(buffer) > 8192:
            loop.quit()
            return False
        while b"\n" in buffer:
            line, _, rest = buffer.partition(b"\n")
            buffer[:] = rest
            try:
                value = json.loads(line)
                if isinstance(value, dict):
                    backend.command(value)
            except (ValueError, TypeError):
                loop.quit()
                return False
        return True
    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, input_ready)
    try:
        loop.run()
    finally:
        backend.close()


if __name__ == "__main__":
    main()
