#!/usr/bin/env python3
"""Private fprintd/login1 fixture. Does not load libfprint, hardware or PAM."""
import json
import os
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

FPRINT = "net.reactivated.Fprint"
DEVICE = FPRINT + ".Device"
CONTROL = "org.putkin.FingerprintFixture"
PROPERTIES = "org.freedesktop.DBus.Properties"


class Device(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, "/net/reactivated/Fprint/Device/0")
        self.calls = []

    @dbus.service.method(DEVICE, in_signature="s", out_signature="")
    def Claim(self, username):
        self.calls.append("Claim")

    @dbus.service.method(DEVICE, in_signature="s", out_signature="")
    def VerifyStart(self, finger):
        self.calls.append("VerifyStart")
        self.VerifyFingerSelected("right-index-finger")

    @dbus.service.method(DEVICE, in_signature="", out_signature="")
    def VerifyStop(self):
        self.calls.append("VerifyStop")

    @dbus.service.method(DEVICE, in_signature="", out_signature="")
    def Release(self):
        self.calls.append("Release")

    @dbus.service.signal(DEVICE, signature="s")
    def VerifyFingerSelected(self, finger):
        pass

    @dbus.service.signal(DEVICE, signature="sb")
    def VerifyStatus(self, status, done):
        pass


class Manager(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, "/net/reactivated/Fprint/Manager")
        self.bus = bus
        self.device = Device(bus)

    @dbus.service.method(FPRINT + ".Manager", in_signature="", out_signature="o")
    def GetDefaultDevice(self):
        self.device.calls.append("GetDefaultDevice")
        return "/net/reactivated/Fprint/Device/0"

    @dbus.service.method(CONTROL, in_signature="sb", out_signature="")
    def Emit(self, status, done):
        self.device.VerifyStatus(status, done)

    @dbus.service.method(CONTROL, in_signature="", out_signature="s")
    def Snapshot(self):
        return json.dumps(self.device.calls)

    @dbus.service.method(CONTROL, in_signature="b", out_signature="")
    def Own(self, own):
        if own:
            self.bus.request_name(FPRINT, dbus.bus.NAME_FLAG_DO_NOT_QUEUE)
        else:
            self.bus.release_name(FPRINT)


class Login(dbus.service.Object):
    @dbus.service.method(PROPERTIES, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        assert interface == "org.freedesktop.login1.Manager" and name == "PreparingForSleep"
        return dbus.Boolean(False)


if __name__ == "__main__":
    marker = Path(os.environ["PUTKIN_TEST_MARKER"])
    assert marker.is_file() and str(marker).startswith("/tmp/")
    assert os.environ["DBUS_SYSTEM_BUS_ADDRESS"] == os.environ["DBUS_SESSION_BUS_ADDRESS"]
    assert str(marker.parent) in os.environ["DBUS_SYSTEM_BUS_ADDRESS"]
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    for name in (FPRINT, CONTROL, "org.freedesktop.login1"):
        assert bus.request_name(name, dbus.bus.NAME_FLAG_DO_NOT_QUEUE) == dbus.bus.REQUEST_NAME_REPLY_PRIMARY_OWNER
    manager = Manager(bus)
    login = Login(bus, "/org/freedesktop/login1")
    GLib.MainLoop().run()
