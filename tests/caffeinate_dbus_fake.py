"""Private login1 fixture with real Unix FD lifetime and BlockInhibited signals."""
import json
import os
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

LOGIN = "org.freedesktop.login1"
MANAGER = LOGIN + ".Manager"
PROPERTIES = "org.freedesktop.DBus.Properties"
CONTROL = "org.putkin.CaffeinateFixture"


class Fixture(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, "/org/freedesktop/login1")
        self.leases = {}
        self.events = []
        self.behavior = "ok"
        self.pending = []

    def blocked(self):
        return ":".join(sorted({flag for lease in self.leases.values() for flag in lease.split(":")}))

    @dbus.service.signal(PROPERTIES, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    def changed(self):
        self.PropertiesChanged(MANAGER, {"BlockInhibited": self.blocked()}, [])

    @dbus.service.method(MANAGER, in_signature="s", out_signature="o")
    def GetSession(self, identifier):
        assert identifier == "auto"
        return "/org/freedesktop/login1/session/fixture"

    @dbus.service.method(PROPERTIES, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        assert interface == MANAGER and name == "BlockInhibited"
        return self.blocked()

    @dbus.service.method(MANAGER, in_signature="ssss", out_signature="h", async_callbacks=("reply", "error"))
    def Inhibit(self, what, who, why, mode, reply, error):
        assert mode == "block" and who == "Putkin Caffeinate", (what, who, why, mode)
        self.events.append(["request", str(what), str(mode), len(self.leases)])
        if self.behavior == "deny":
            error(dbus.exceptions.DBusException("Fixture denied", name="org.freedesktop.DBus.Error.AccessDenied"))
            return
        if self.behavior == "timeout":
            self.pending.append((reply, error))
            return
        read_fd, write_fd = os.pipe()
        self.leases[read_fd] = str(what)
        GLib.io_add_watch(read_fd, GLib.IO_HUP | GLib.IO_ERR, self.released)
        self.changed()
        try:
            reply(dbus.types.UnixFd(write_fd))
        finally:
            os.close(write_fd)

    def released(self, fd, _condition):
        self.events.append(["release", self.leases.pop(fd)])
        os.close(fd)
        self.changed()
        return False

    @dbus.service.method(CONTROL, out_signature="s")
    def Snapshot(self):
        return json.dumps({"leases": list(self.leases.values()), "blocked": self.blocked(), "events": self.events})

    @dbus.service.method(CONTROL, in_signature="s")
    def Configure(self, behavior):
        self.behavior = str(behavior)


if __name__ == "__main__":
    marker = Path(os.environ["PUTKIN_TEST_MARKER"])
    assert marker.is_file() and str(marker).startswith("/tmp/")
    address = "unix:path=" + str(marker.parent / "bus")
    assert os.environ["DBUS_SYSTEM_BUS_ADDRESS"] == os.environ["DBUS_SESSION_BUS_ADDRESS"] == address
    DBusGMainLoop(set_as_default=True)
    bus = dbus.bus.BusConnection(address)
    name = dbus.service.BusName(LOGIN, bus=bus, do_not_queue=True)
    fixture = Fixture(bus)
    GLib.MainLoop().run()
