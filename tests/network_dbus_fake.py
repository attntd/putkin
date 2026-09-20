#!/usr/bin/env python3
"""Small NetworkManager peer. Never connects to the host bus or hardware."""
import json
import os
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

NM = "org.freedesktop.NetworkManager"
BASE = "/org/freedesktop/NetworkManager"
PROPS = "org.freedesktop.DBus.Properties"
DEV = NM + ".Device"
WIFI = DEV + ".Wireless"
WIRED = DEV + ".Wired"
AP = NM + ".AccessPoint"
PROFILE = NM + ".Settings.Connection"
ACTIVE = NM + ".Connection.Active"


class Properties(dbus.service.Object):
    def __init__(self, bus, path, values):
        super().__init__(bus, path)
        self.path, self.values = path, values
        self.reads = 0

    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        self.reads += 1
        return self.values.get(str(interface), {})

    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        return self.values[str(interface)][str(name)]

    @dbus.service.signal(PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    def update(self, interface, **changes):
        props = self.values[interface]
        for name, value in changes.items():
            if isinstance(props[name], dbus.Array):
                props[name] = dbus.Array(value, signature=props[name].signature)
            else:
                props[name] = type(props[name])(value)
        self.PropertiesChanged(interface, {name: props[name] for name in changes}, [])


class Profile(Properties):
    def __init__(self, bus, index, ssid, security):
        super().__init__(bus, BASE + f"/Settings/{index}", {PROFILE: dict(Unsaved=dbus.Boolean(True), Flags=dbus.UInt32(0))})
        self.ssid, self.security, self.psk_ok, self.updates = ssid, security, False, 0
        self.bus, self.update_pids = bus, []

    @dbus.service.method(PROFILE, in_signature="", out_signature="a{sa{sv}}")
    def GetSettings(self):
        data = {"connection": {"id": self.ssid, "uuid": "00000000-0000-0000-0000-" + self.path.rsplit("/", 1)[1].zfill(12),
                               "type": "802-11-wireless", "timestamp": dbus.UInt64(100)},
                "802-11-wireless": {"ssid": dbus.ByteArray(self.ssid.encode()), "mode": "infrastructure"}}
        if self.security:
            data["802-11-wireless-security"] = {"key-mgmt": "wpa-psk"}
        return data  # GetSettings never returns secrets.

    @dbus.service.method(PROFILE, in_signature="a{sa{sv}}", out_signature="", sender_keyword="sender")
    def Update(self, values, sender=None):
        secret = str(values.get("802-11-wireless-security", {}).get("psk", ""))
        self.psk_ok = secret == "putkin-" + "private-" + "psk-07"
        self.updates += 1
        self.update_pids.append(int(self.bus.call_blocking("org.freedesktop.DBus", "/org/freedesktop/DBus",
            "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", (sender,))))
        self.Updated()

    @dbus.service.signal(PROFILE)
    def Updated(self):
        pass


class Active(Properties):
    def __init__(self, bus, index, profile):
        super().__init__(bus, BASE + f"/ActiveConnection/{index}", {ACTIVE: dict(Connection=dbus.ObjectPath(profile.path), State=dbus.UInt32(1))})

    @dbus.service.signal(ACTIVE, signature="uu")
    def StateChanged(self, state, reason):
        pass


class Device(Properties):
    def __init__(self, manager, index, wifi):
        self.manager = manager
        values = {DEV: dict(DeviceType=dbus.UInt32(2 if wifi else 1), Interface=dbus.String("wlan0" if wifi else "eth0"),
                           HwAddress=dbus.String("00:00:00:00:00:07"), Managed=dbus.Boolean(True), State=dbus.UInt32(30),
                           Autoconnect=dbus.Boolean(True), AvailableConnections=dbus.Array([], signature="o"),
                           ActiveConnection=dbus.ObjectPath("/"), InterfaceFlags=dbus.UInt32(3))}
        if wifi:
            values[WIFI] = dict(LastScan=dbus.Int64(-1), WirelessCapabilities=dbus.UInt32(0x7ff), ActiveAccessPoint=dbus.ObjectPath("/"), Mode=dbus.UInt32(2))
        else:
            values[WIRED] = dict(Speed=dbus.UInt32(1000))
        super().__init__(manager.bus, BASE + f"/Devices/{index}", values)
        self.aps, self.profiles = [], []
        self.active = None
        self.scan_count, self.disconnect_count, self.generation = 0, 0, 0

    @dbus.service.method(DEV, in_signature="", out_signature="")
    def Disconnect(self):
        self.disconnect_count += 1
        self.generation += 1
        if self.active:
            self.active.update(ACTIVE, State=4)
            self.active.StateChanged(4, 2)
        self.update(DEV, State=30, ActiveConnection="/")

    @dbus.service.signal(DEV, signature="uuu")
    def StateChanged(self, state, previous, reason):
        pass

    @dbus.service.method(WIFI, in_signature="", out_signature="ao")
    def GetAllAccessPoints(self):
        return [ap.path for ap in self.aps]

    @dbus.service.method(WIFI, in_signature="a{sv}", out_signature="")
    def RequestScan(self, options):
        self.scan_count += 1

    @dbus.service.signal(WIFI, signature="o")
    def AccessPointAdded(self, path):
        pass

    @dbus.service.signal(WIFI, signature="o")
    def AccessPointRemoved(self, path):
        pass


class Manager(Properties):
    def __init__(self, bus):
        self.bus = bus
        super().__init__(bus, BASE, {NM: dict(WirelessEnabled=dbus.Boolean(True), WirelessHardwareEnabled=dbus.Boolean(True),
            Connectivity=dbus.UInt32(4), ConnectivityCheckAvailable=dbus.Boolean(True), ConnectivityCheckEnabled=dbus.Boolean(True))})
        self.wifi, self.wired = Device(self, 1, True), Device(self, 2, False)
        self.devices = [self.wifi, self.wired]
        self.events, self.actives = [], []
        self.radio_mode = "ok"
        self.hold = False
        self.profiles = {}
        for index, (ssid, secure) in enumerate([("Saved", True), ("Open", False), ("PSK", True), ("<b>hjkl & goście</b>", False), ("Open", False)], 1):
            ap = Properties(bus, BASE + f"/AccessPoint/{index}", {AP: dict(Ssid=dbus.ByteArray(ssid.encode()), Strength=dbus.Byte(80-index),
                Flags=dbus.UInt32(1 if secure else 0), WpaFlags=dbus.UInt32(0), RsnFlags=dbus.UInt32(0x188 if secure else 0), Mode=dbus.UInt32(2))})
            self.wifi.aps.append(ap)
        saved = self.profile("Saved", True)
        saved.psk_ok = True

    def profile(self, ssid, security):
        if ssid not in self.profiles:
            obj = Profile(self.bus, len(self.profiles) + 1, ssid, security)
            self.profiles[ssid] = obj
            self.wifi.profiles.append(obj)
            self.wifi.update(DEV, AvailableConnections=[p.path for p in self.wifi.profiles])
        return self.profiles[ssid]

    @dbus.service.method(NM, in_signature="", out_signature="ao")
    def GetAllDevices(self):
        return [device.path for device in self.devices]

    @dbus.service.method(NM, in_signature="", out_signature="u")
    def CheckConnectivity(self):
        self.events.append(["check"])
        return self.values[NM]["Connectivity"]

    @dbus.service.method(PROPS, in_signature="ssv", out_signature="")
    def Set(self, interface, name, value):
        assert str(interface) == NM and str(name) == "WirelessEnabled"
        self.events.append(["radio", bool(value)])
        if self.radio_mode == "deny":
            raise dbus.exceptions.DBusException("Test permission denied", name=NM + ".PermissionDenied")
        if self.radio_mode != "ignore":
            self.update(NM, WirelessEnabled=bool(value))

    @dbus.service.method(NM, in_signature="a{sa{sv}}oo", out_signature="oo")
    def AddAndActivateConnection(self, values, device, specific):
        ap = next(ap for ap in self.wifi.aps if ap.path == str(specific))
        props = ap.values[AP]
        ssid = bytes(props["Ssid"]).decode()
        profile = self.profile(ssid, bool(props["Flags"]))
        secret = str(values.get("802-11-wireless-security", {}).get("psk", ""))
        if secret:
            profile.psk_ok = secret == "putkin-" + "private-" + "psk-07"
        self.events.append(["add", ssid, bool(secret)])
        return profile.path, self.activate(profile)

    @dbus.service.method(NM, in_signature="ooo", out_signature="o")
    def ActivateConnection(self, profile, device, specific):
        obj = next(p for p in self.profiles.values() if p.path == str(profile))
        self.events.append(["activate", obj.ssid])
        return self.activate(obj)

    def activate(self, profile):
        device = self.wifi
        device.generation += 1
        generation = device.generation
        active = Active(self.bus, len(self.actives) + 1, profile)
        self.actives.append(active)
        device.active = active
        device.update(DEV, State=40, ActiveConnection=active.path)

        def finish():
            if generation != device.generation:
                return False
            if profile.security and not profile.psk_ok:
                device.update(DEV, State=120)
                device.StateChanged(120, 40, 7)
                active.update(ACTIVE, State=4)
                active.StateChanged(4, 3)
            else:
                device.update(DEV, State=100)
                active.update(ACTIVE, State=2)
                active.StateChanged(2, 1)
            return False

        if not self.hold:
            GLib.timeout_add(160, finish)
        return active.path

    @dbus.service.signal(NM, signature="o")
    def DeviceAdded(self, path):
        pass

    @dbus.service.signal(NM, signature="o")
    def DeviceRemoved(self, path):
        pass


class Control(dbus.service.Object):
    def __init__(self, bus, manager):
        super().__init__(bus, "/Test")
        self.bus, self.manager = bus, manager
        self.present = True

    @dbus.service.method("org.putkin.NetworkTest", in_signature="s", out_signature="s")
    def Command(self, data):
        request = json.loads(str(data))
        op, nm = request["op"], self.manager
        if op == "properties":
            nm.update(NM, **request["values"])
        elif op == "radioMode":
            nm.radio_mode = request["mode"]
        elif op == "hold":
            nm.hold = request["value"]
        elif op == "ethernet":
            nm.wired.update(DEV, State=100 if request["value"] else 30)
        elif op == "wifiDevice":
            if request["value"] and nm.wifi not in nm.devices:
                nm.devices.insert(0, nm.wifi)
                nm.DeviceAdded(nm.wifi.path)
            elif not request["value"] and nm.wifi in nm.devices:
                nm.devices.remove(nm.wifi)
                nm.DeviceRemoved(nm.wifi.path)
        elif op == "owner":
            if request["value"]:
                self.bus.request_name(NM)
            else:
                self.bus.release_name(NM)
            self.present = request["value"]
        elif op == "strength":
            nm.wifi.aps[0].update(AP, Strength=request["value"])
        elif op != "snapshot":
            raise ValueError(op)
        return json.dumps(dict(events=nm.events, scans=nm.wifi.scan_count, disconnects=nm.wifi.disconnect_count,
                               reads=nm.reads, updates=sum(p.updates for p in nm.profiles.values()),
                               update_pids=[pid for p in nm.profiles.values() for pid in p.update_pids]))


if __name__ == "__main__":
    address = os.environ.get("DBUS_SYSTEM_BUS_ADDRESS", "")
    marker = Path(os.environ.get("PUTKIN_TEST_MARKER", "/nonexistent"))
    if not marker.is_file() or address != os.environ.get("DBUS_SESSION_BUS_ADDRESS") or not address.startswith("unix:path=/tmp/pk-"):
        raise SystemExit("Private test bus required")
    DBusGMainLoop(set_as_default=True)
    bus = dbus.bus.BusConnection(address)
    bus.request_name(NM)
    manager = Manager(bus)
    control = Control(bus, manager)
    bus.request_name("org.putkin.NetworkTest")
    GLib.MainLoop().run()
