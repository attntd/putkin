#!/usr/bin/env python3
"""Private login1 with real inhibitor FDs; never import or invoke PAM."""
import json
import os
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

LOGIN = "org.freedesktop.login1"
MANAGER = LOGIN + ".Manager"
SESSION = LOGIN + ".Session"
SAVER = "org.freedesktop.ScreenSaver"
CONTROL = "org.putkin.SessionFixture"
PROPERTIES = "org.freedesktop.DBus.Properties"


def isolated():
    marker = Path(os.environ["PUTKIN_TEST_MARKER"])
    address = "unix:path=" + str(marker.parent / "bus")
    assert marker.is_file() and str(marker).startswith("/tmp/")
    assert os.environ["DBUS_SYSTEM_BUS_ADDRESS"] == os.environ["DBUS_SESSION_BUS_ADDRESS"] == address


class Fixture(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, "/org/freedesktop/login1")
        self.bus = bus
        self.events = []
        self.mode = "ok"
        self.can = {"reboot": "yes", "poweroff": "yes", "suspend": "yes"}
        self.pending = []
        self.leases = {}
        self.blocks = ""
        self.session = Session(bus)

    def action(self, name, args, reply, error):
        self.events.append([name, *args])
        if self.mode == "deny":
            error(dbus.exceptions.DBusException("Denied", name="org.freedesktop.DBus.Error.AccessDenied"))
        elif self.mode == "timeout":
            self.pending.append(reply)
        else:
            reply()

    @dbus.service.method(MANAGER, in_signature="ssss", out_signature="h", async_callbacks=("reply", "error"))
    def Inhibit(self, what, who, why, mode, reply, error):
        r, w = os.pipe()
        self.leases[r] = [str(what), str(mode)]
        def released(fd, _condition):
            self.leases.pop(fd, None)
            os.close(fd)
            return False
        GLib.io_add_watch(r, GLib.IO_HUP | GLib.IO_ERR, released)
        try:
            reply(dbus.types.UnixFd(w))
        finally:
            os.close(w)

    @dbus.service.method(PROPERTIES, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        assert interface == MANAGER and name == "BlockInhibited"
        return self.blocks

    @dbus.service.signal(PROPERTIES, signature="sa{sv}as")
    def PropertiesChanged(self, interface, values, invalidated):
        pass

    @dbus.service.method(CONTROL, in_signature="s", out_signature="")
    def Inhibitors(self, value):
        self.blocks = str(value)
        self.PropertiesChanged(MANAGER, {"BlockInhibited": self.blocks}, [])

    @dbus.service.method(CONTROL, in_signature="", out_signature="s")
    def Leases(self):
        return json.dumps(list(self.leases.values()))

    @dbus.service.method(CONTROL, in_signature="", out_signature="")
    def LockSession(self):
        self.session.Lock()

    @dbus.service.method(MANAGER, in_signature="s", out_signature="o")
    def GetSession(self, identifier):
        if identifier != "test-session":
            raise dbus.exceptions.DBusException("No session", name=LOGIN + ".NoSuchSession")
        return "/org/freedesktop/login1/session/test"

    @dbus.service.method(MANAGER, in_signature="", out_signature="s")
    def CanReboot(self):
        return self.can["reboot"]

    @dbus.service.method(MANAGER, in_signature="", out_signature="s")
    def CanPowerOff(self):
        return self.can["poweroff"]

    @dbus.service.method(MANAGER, in_signature="", out_signature="s")
    def CanSuspend(self):
        return self.can["suspend"]

    @dbus.service.method(MANAGER, in_signature="", out_signature="s")
    def CanSuspendThenHibernate(self):
        return self.can["suspend"]

    @dbus.service.method(MANAGER, in_signature="b", out_signature="", async_callbacks=("reply", "error"))
    def Reboot(self, interactive, reply, error):
        self.action("reboot", [bool(interactive)], reply, error)

    @dbus.service.method(MANAGER, in_signature="b", out_signature="", async_callbacks=("reply", "error"))
    def PowerOff(self, interactive, reply, error):
        self.action("poweroff", [bool(interactive)], reply, error)

    @dbus.service.method(MANAGER, in_signature="b", out_signature="", async_callbacks=("reply", "error"))
    def Suspend(self, interactive, reply, error):
        self.action("suspend", [bool(interactive)], reply, error)

    @dbus.service.method(MANAGER, in_signature="b", out_signature="", async_callbacks=("reply", "error"))
    def SuspendThenHibernate(self, interactive, reply, error):
        self.action("suspendThenHibernate", [bool(interactive)], reply, error)

    @dbus.service.method(MANAGER, in_signature="s", out_signature="", async_callbacks=("reply", "error"))
    def TerminateSession(self, identifier, reply, error):
        self.action("logout", [str(identifier)], reply, error)

    @dbus.service.signal(MANAGER, signature="b")
    def PrepareForSleep(self, sleeping):
        pass

    @dbus.service.method(CONTROL, in_signature="", out_signature="s")
    def Snapshot(self):
        return json.dumps(self.events)

    @dbus.service.method(CONTROL, in_signature="", out_signature="")
    def Clear(self):
        self.events = []

    @dbus.service.method(CONTROL, in_signature="s", out_signature="")
    def Mode(self, mode):
        self.mode = str(mode)

    @dbus.service.method(CONTROL, in_signature="ss", out_signature="")
    def Capability(self, action, value):
        self.can[str(action)] = str(value)

    @dbus.service.method(CONTROL, in_signature="b", out_signature="")
    def Sleep(self, sleeping):
        self.PrepareForSleep(sleeping)

    @dbus.service.method(CONTROL, in_signature="", out_signature="")
    def CompleteLate(self):
        for reply in self.pending:
            reply()
        self.pending = []

    @dbus.service.method(CONTROL, in_signature="sb", out_signature="")
    def Owner(self, name, active):
        if active:
            self.bus.request_name(str(name), dbus.bus.NAME_FLAG_DO_NOT_QUEUE)
        else:
            self.bus.release_name(str(name))

    @dbus.service.method(CONTROL, in_signature="b", out_signature="")
    def OwnSession(self, own):
        self.session.uid = os.getuid() if own else os.getuid() + 1


class Session(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, "/org/freedesktop/login1/session/test")
        self.uid = os.getuid()

    @dbus.service.method(SESSION, in_signature="b", out_signature="")
    def SetLockedHint(self, value):
        self.locked = bool(value)

    @dbus.service.method(SESSION, in_signature="b", out_signature="")
    def SetIdleHint(self, value):
        self.idle = bool(value)

    @dbus.service.signal(SESSION, signature="")
    def Lock(self):
        pass

    @dbus.service.method(PROPERTIES, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        assert interface == SESSION
        return {"Id": "test-session", "User": dbus.Struct((dbus.UInt32(self.uid), dbus.ObjectPath("/user")), signature="uo"),
                "Active": dbus.Boolean(True), "Remote": dbus.Boolean(False), "Class": "user", "Type": "wayland"}



if __name__ == "__main__":
    isolated()
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    for name in (LOGIN, CONTROL):
        bus.request_name(name, dbus.bus.NAME_FLAG_DO_NOT_QUEUE)
    fixture = Fixture(bus)
    GLib.MainLoop().run()
