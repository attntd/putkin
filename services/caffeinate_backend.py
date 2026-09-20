"""Hold a login1 inhibitor only while Caffeinate is enabled.

The controlling QML pipe owns this process. EOF, owner loss, or process exit
closes every descriptor; nothing is persisted or automatically reacquired.
"""
import json
import os
import sys

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

LOGIN = "org.freedesktop.login1"
PATH = "/org/freedesktop/login1"
MANAGER = LOGIN + ".Manager"
MODES = {"presentation": "idle:sleep", "background": "sleep"}


class Inhibitor:
    def __init__(self, bus, emit, quit_loop):
        self.bus, self.emit, self.quit = bus, emit, quit_loop
        self.fd = None
        self.mode = "off"
        self.owner = str(bus.get_name_owner(LOGIN))
        self.watch = bus.add_signal_receiver(self.owner_changed, "NameOwnerChanged", "org.freedesktop.DBus",
            bus_name="org.freedesktop.DBus", path="/org/freedesktop/DBus", arg0=LOGIN)
        bus.call_on_disconnection(self.disconnected)

    def close(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None
        self.mode = "off"

    def request(self, mode):
        if mode not in ("off", *MODES):
            self.emit({"mode": self.mode, "error": "Nieprawidłowy tryb Caffeinate."})
            return
        try:
            if mode == "off":
                self.close()
            elif mode != self.mode:
                proxy = self.bus.get_object(self.owner, PATH, introspect=False)
                method = proxy.get_dbus_method("Inhibit", MANAGER)
                result = method(MODES[mode], "Putkin Caffeinate",
                    "Prezentacja" if mode == "presentation" else "Praca w tle", "block", timeout=3)
                new_fd = result.take()
                try:
                    os.set_inheritable(new_fd, False)
                except OSError:
                    os.close(new_fd)
                    raise
                # Acquire before release: a mode change never leaves a gap.
                self.close()
                self.fd, self.mode = new_fd, mode
            self.emit({"mode": self.mode, "error": ""})
        except (dbus.DBusException, OSError, AttributeError):
            self.emit({"mode": self.mode, "error": "Logind nie potwierdził blokady usypiania. Sprawdź dostępność usługi i uprawnienia."})
        if self.mode == "off":
            self.quit()

    def owner_changed(self, _name, old, _new):
        if str(old) == self.owner:
            self.disconnected(self.bus)

    def disconnected(self, _bus):
        active = self.mode != "off"
        self.close()
        if active:
            self.emit({"mode": "off", "error": "Utracono blokadę usypiania: usługa logind została rozłączona."})
        self.quit()


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in MODES:
        return 2
    DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()
    def emit(value):
        print(json.dumps(value, ensure_ascii=False), flush=True)
    try:
        inhibitor = Inhibitor(dbus.SystemBus(), emit, loop.quit)
    except dbus.DBusException:
        emit({"mode": "off", "error": "Logind jest niedostępny; Caffeinate nie zostało włączone."})
        return 1
    buffer = bytearray()
    def input_ready(_fd, condition):
        if condition & (GLib.IO_HUP | GLib.IO_ERR):
            loop.quit()
            return False
        chunk = os.read(sys.stdin.fileno(), 4096)
        if not chunk:
            loop.quit()
            return False
        buffer.extend(chunk)
        if len(buffer) > 4096:
            loop.quit()
            return False
        while b"\n" in buffer:
            line, _, tail = buffer.partition(b"\n")
            buffer[:] = tail
            try:
                request = json.loads(line)
                if not isinstance(request, dict):
                    raise ValueError("invalid request")
                inhibitor.request(request.get("mode"))
            except (ValueError, TypeError):
                loop.quit()
                return False
        return True
    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, input_ready)
    try:
        inhibitor.request(sys.argv[1])
        if inhibitor.mode != "off":
            loop.run()
    finally:
        inhibitor.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
