#!/usr/bin/env python3
"""UPower + real SNI/DBusMenu peers, exclusively on the wrapper's private bus."""
import json
import os
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

PROPS = "org.freedesktop.DBus.Properties"
POWER = "org.freedesktop.UPower"
DEVICE = POWER + ".Device"
DISPLAY = "/org/freedesktop/UPower/devices/DisplayDevice"
PROFILES = "org.freedesktop.UPower.PowerProfiles"
SNI = "org.kde.StatusNotifierItem"
MENU = "com.canonical.dbusmenu"


class Properties(dbus.service.Object):
    def __init__(self, bus, path, interface, properties):
        super().__init__(bus, path)
        self.interface, self.properties = interface, properties
        self.reads = 0

    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        self.reads += 1
        return self.properties if interface == self.interface else {}

    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        if interface != self.interface:
            raise dbus.exceptions.DBusException("Unknown interface")
        return self.properties[name]

    @dbus.service.signal(PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changed, invalidated):
        pass

    def update(self, changes):
        for key, value in changes.items():
            self.properties[key] = type(self.properties[key])(value)
        self.PropertiesChanged(self.interface, {key: self.properties[key] for key in changes}, [])


def battery_properties(**updates):
    result = dict(Type=dbus.UInt32(2), PowerSupply=dbus.Boolean(True),
                  Energy=dbus.Double(36), EnergyFull=dbus.Double(50), EnergyRate=dbus.Double(9),
                  TimeToEmpty=dbus.Int64(14400), TimeToFull=dbus.Int64(0),
                  Percentage=dbus.Double(72), IsPresent=dbus.Boolean(True), State=dbus.UInt32(2),
                  Capacity=dbus.Double(95), IconName=dbus.String("battery-good-symbolic"),
                  NativePath=dbus.String("BAT0"), Model=dbus.String("Private test battery"))
    for key, value in updates.items():
        result[key] = type(result[key])(value)
    return result


class Power(Properties):
    def __init__(self, bus):
        super().__init__(bus, "/org/freedesktop/UPower", POWER,
                         dict(OnBattery=dbus.Boolean(True), DaemonVersion=dbus.String("1.91.4")))
        self.display = Properties(bus, DISPLAY, DEVICE, battery_properties())
        self.mouse = Properties(bus, "/org/freedesktop/UPower/devices/mouse_test", DEVICE,
                                battery_properties(Type=5, PowerSupply=False, Percentage=3, NativePath="mouse"))

    @dbus.service.method(POWER, in_signature="", out_signature="o")
    def GetDisplayDevice(self):
        return DISPLAY

    @dbus.service.method(POWER, in_signature="", out_signature="ao")
    def EnumerateDevices(self):
        return ["/org/freedesktop/UPower/devices/mouse_test"]

    @dbus.service.signal(POWER, signature="o")
    def DeviceAdded(self, path):
        pass

    @dbus.service.signal(POWER, signature="o")
    def DeviceRemoved(self, path):
        pass


class PowerProfiles(Properties):
    def __init__(self, bus):
        super().__init__(bus, "/org/freedesktop/UPower/PowerProfiles", PROFILES,
                         dict(ActiveProfile=dbus.String("balanced"), PerformanceDegraded=dbus.String(""),
                              Profiles=self.profiles(True)))
        self.mode = "success"
        self.bus = bus
        self.writes = []

    @staticmethod
    def profiles(performance):
        return dbus.Array([dbus.Dictionary({"Profile": dbus.String(value)}, signature="sv")
                           for value in ["power-saver", "balanced"] + (["performance"] if performance else [])], signature="a{sv}")

    @dbus.service.method(PROPS, in_signature="ssv", out_signature="")
    def Set(self, interface, name, value):
        if interface != PROFILES or name != "ActiveProfile" or value not in ["power-saver", "balanced", "performance"]:
            raise dbus.exceptions.DBusException("Invalid property")
        self.writes.append(str(value))
        if self.mode == "denied":
            raise dbus.exceptions.DBusException("Denied", name="org.freedesktop.DBus.Error.AccessDenied")
        if self.mode == "success":
            self.update({"ActiveProfile": str(value)})
        elif self.mode == "drop":
            self.bus.release_name(PROFILES)
        # 'ignored' deliberately returns success without changing state.


class Menu(Properties):
    def __init__(self, bus, events):
        super().__init__(bus, "/Menu", MENU, dict(Version=dbus.UInt32(4),
                         TextDirection=dbus.String("ltr"), Status=dbus.String("normal"),
                         IconThemePath=dbus.Array([], signature="s")))
        self.events = events
        self.hidden = False
        self.revision = 1

    def layout(self, id, properties=None, children=None):
        return dbus.Struct((dbus.Int32(id), dbus.Dictionary(properties or {}, signature="sv"),
                            dbus.Array(children or [], signature="v")), signature="ia{sv}av", variant_level=1)

    def root(self):
        sub = self.layout(4, {"label": "_Opcje", "children-display": "submenu"},
                          [self.layout(40, {"label": "Szczegóły"})])
        children = [self.layout(1, {"label": "_Otwórz"}),
                    self.layout(2, {"label": "Wyłączone", "enabled": False}),
                    self.layout(3, {"type": "separator"})]
        if not self.hidden:
            children.append(sub)
        children += [self.layout(5, {"label": "Synchronizacja", "toggle-type": "checkmark", "toggle-state": dbus.Int32(1)}),
                     self.layout(6, {"label": "Ukryte", "visible": False})]
        return self.layout(0, {"children-display": "submenu"}, children)

    @dbus.service.method(MENU, in_signature="iias", out_signature="u(ia{sv}av)")
    def GetLayout(self, parent, depth, properties):
        self.events.append(["layout", int(parent)])
        root = self.root()
        if parent == 4:
            root = self.layout(4, {"label": "Opcje", "children-display": "submenu"}, [self.layout(40, {"label": "Szczegóły"})])
        return dbus.UInt32(self.revision), root

    @dbus.service.method(MENU, in_signature="i", out_signature="b")
    def AboutToShow(self, id):
        self.events.append(["about", int(id)])
        return False

    @dbus.service.method(MENU, in_signature="isvu", out_signature="")
    def Event(self, id, event, data, timestamp):
        self.events.append([str(event), int(id)])

    @dbus.service.signal(MENU, signature="ui")
    def LayoutUpdated(self, revision, parent):
        pass

    @dbus.service.signal(MENU, signature="a(ia{sv})a(ias)")
    def ItemsPropertiesUpdated(self, changed, removed):
        pass


class TrayItem(Properties):
    def __init__(self, address, number, events):
        self.bus = dbus.bus.BusConnection(address)
        self.events, self.number = events, number
        pixmaps = dbus.Array([], signature="(iiay)")
        if number != 0:
            pixmaps.append(dbus.Struct((20, 20, dbus.ByteArray(bytes([255, 148, 226, 213]) * 400)), signature="iiay"))
        super().__init__(self.bus, "/StatusNotifierItem", SNI,
                         dict(Id=dbus.String(f"app{number}"), Title=dbus.String(f"Aplikacja {number}"),
                              Category=dbus.String("ApplicationStatus"), Status=dbus.String("Active"),
                              WindowId=dbus.UInt32(0), IconName=dbus.String(""), IconPixmap=pixmaps,
                              OverlayIconName=dbus.String(""), OverlayIconPixmap=dbus.Array([], signature="(iiay)"),
                              AttentionIconName=dbus.String(""), AttentionIconPixmap=dbus.Array([], signature="(iiay)"),
                              AttentionMovieName=dbus.String(""), IconThemePath=dbus.String(""),
                              ToolTip=dbus.Struct(("", dbus.Array([], signature="(iiay)"), f"Klient {number}", "Prywatny test"), signature="sa(iiay)ss"),
                              ItemIsMenu=dbus.Boolean(number == 1), Menu=dbus.ObjectPath("/Menu")))
        self.menu = Menu(self.bus, events)
        self.watch = self.bus.watch_name_owner("org.kde.StatusNotifierWatcher", self.register)

    def register(self, owner):
        if owner:
            watcher = self.bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher")
            watcher.RegisterStatusNotifierItem("/StatusNotifierItem", dbus_interface="org.kde.StatusNotifierWatcher")

    @dbus.service.method(SNI, in_signature="ii", out_signature="")
    def Activate(self, x, y):
        self.events.append(["activate", self.number])

    @dbus.service.method(SNI, in_signature="ii", out_signature="")
    def SecondaryActivate(self, x, y):
        self.events.append(["secondary", self.number])

    @dbus.service.method(SNI, in_signature="ii", out_signature="")
    def ContextMenu(self, x, y):
        self.events.append(["context", self.number])

    @dbus.service.method(SNI, in_signature="is", out_signature="")
    def Scroll(self, delta, orientation):
        self.events.append(["scroll", self.number, int(delta), str(orientation)])

    @dbus.service.signal(SNI, signature="")
    def NewTitle(self):
        pass

    @dbus.service.signal(SNI, signature="s")
    def NewStatus(self, status):
        pass

    @dbus.service.signal(SNI, signature="")
    def NewIcon(self):
        pass

    def close(self):
        self.watch.cancel()
        self.remove_from_connection()
        self.menu.remove_from_connection()
        self.bus.close()


class Control(dbus.service.Object):
    def __init__(self, bus, address):
        super().__init__(bus, "/Test")
        self.bus, self.address = bus, address
        self.events, self.items = [], {}
        self.power = Power(bus)
        self.profiles = PowerProfiles(bus)

    @dbus.service.method("org.putkin.Test", in_signature="s", out_signature="s")
    def Command(self, text):
        command = json.loads(text)
        op = command["op"]
        if op == "power":
            if command["present"]:
                self.bus.request_name(POWER)
            else:
                self.bus.release_name(POWER)
        elif op == "profiles":
            if "present" in command:
                (self.bus.request_name if command["present"] else self.bus.release_name)(PROFILES)
            if "mode" in command:
                self.profiles.mode = command["mode"]
            if "profile" in command:
                self.profiles.update({"ActiveProfile": command["profile"]})
            if "performance" in command:
                self.profiles.properties["Profiles"] = self.profiles.profiles(command["performance"])
                self.profiles.PropertiesChanged(PROFILES, {"Profiles": self.profiles.properties["Profiles"]}, [])
            if "degradation" in command:
                self.profiles.update({"PerformanceDegraded": command["degradation"]})
        elif op == "battery":
            self.power.display.update(command["values"])
        elif op == "add":
            for number in range(command["count"]):
                if number not in self.items:
                    self.items[number] = TrayItem(self.address, number, self.events)
        elif op == "remove":
            self.items.pop(command["index"]).close()
        elif op == "hideSubmenu":
            menu = self.items[command["index"]].menu
            menu.hidden = True
            menu.revision += 1
            menu.LayoutUpdated(menu.revision, 0)
        elif op == "title":
            item = self.items[command["index"]]
            item.properties["Title"] = dbus.String(command["text"])
            item.NewTitle()
        elif op == "passive":
            item = self.items[command["index"]]
            item.properties["Status"] = dbus.String("Passive")
            item.NewStatus("Passive")
        elif op == "signalIcon":
            item = self.items[command["index"]]
            pixels = bytearray()
            for y in range(32):
                for x in range(32):
                    badge = command["unread"] and x >= 16 and y < 16
                    pixels.extend([255, 243, 68, 50] if badge else [255, 38, 59, 250])
            item.properties["IconPixmap"] = dbus.Array([
                dbus.Struct((32, 32, dbus.ByteArray(pixels)), signature="iiay")], signature="(iiay)")
            item.NewIcon()
        elif op != "snapshot":
            raise ValueError(op)
        return json.dumps({"events": self.events, "reads": self.power.display.reads, "items": len(self.items),
                           "profileWrites": self.profiles.writes, "profileReads": self.profiles.reads})


if __name__ == "__main__":
    marker = Path(os.environ["PUTKIN_TEST_MARKER"])
    address = os.environ["DBUS_SESSION_BUS_ADDRESS"]
    if not marker.is_file() or not str(marker.parent).startswith("/tmp/pk-") or str(marker.parent) not in address:
        raise SystemExit("Only an explicitly marked private bus is permitted")
    DBusGMainLoop(set_as_default=True)
    bus = dbus.bus.BusConnection(address)
    bus.request_name("org.putkin.Test")
    control = Control(bus, address)
    bus.request_name(PROFILES)
    if os.environ.get("PUTKIN_TEST_POWER_PRESENT") == "1":
        bus.request_name(POWER)
    print("PUTKIN_STATUS_FAKE_READY", flush=True)
    GLib.MainLoop().run()
