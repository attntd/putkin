#!/usr/bin/env python3
"""BlueZ protocol fixture. Refuses to run outside the wrapper's private bus."""
import json
import os
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

PROPS = "org.freedesktop.DBus.Properties"
OBJECTS = "org.freedesktop.DBus.ObjectManager"
ADAPTER = "org.bluez.Adapter1"
DEVICE = "org.bluez.Device1"
BATTERY = "org.bluez.Battery1"


class Rejected(dbus.exceptions.DBusException):
    _dbus_error_name = "org.bluez.Error.Failed"


class Object(dbus.service.Object):
    def __init__(self, server, path, interfaces):
        super().__init__(server.bus, path)
        self.server, self.path, self.interfaces = server, path, interfaces

    @dbus.service.method(PROPS, in_signature="s", out_signature="a{sv}")
    def GetAll(self, interface):
        self.server.control.reads += 1
        return self.interfaces.get(interface, {})

    @dbus.service.method(PROPS, in_signature="ss", out_signature="v")
    def Get(self, interface, name):
        self.server.control.reads += 1
        return self.interfaces[interface][name]

    @dbus.service.method(PROPS, in_signature="ssv", out_signature="", async_callbacks=("reply", "error"))
    def Set(self, interface, name, value, reply, error):
        if interface != ADAPTER or name != "Powered":
            self.server.control.forbidden.append(["Set", interface, name])
            error(Rejected("unsupported property"))
            return
        self.server.control.perform(self, "radio", bool(value), reply, error)

    @dbus.service.signal(PROPS, signature="sa{sv}as")
    def PropertiesChanged(self, interface, changes, invalidated):
        pass

    def update(self, interface, changes):
        properties = self.interfaces[interface]
        for key, value in changes.items():
            properties[key] = type(properties[key])(value)
        self.PropertiesChanged(interface, {k: properties[k] for k in changes}, [])


class Adapter(Object):
    @dbus.service.method(ADAPTER, in_signature="", out_signature="")
    def StartDiscovery(self):
        self.server.control.forbidden.append(["StartDiscovery", self.path])

    @dbus.service.method(ADAPTER, in_signature="", out_signature="")
    def StopDiscovery(self):
        self.server.control.forbidden.append(["StopDiscovery", self.path])

    @dbus.service.method(ADAPTER, in_signature="o", out_signature="")
    def RemoveDevice(self, path):
        self.server.control.forbidden.append(["RemoveDevice", str(path)])


class Device(Object):
    @dbus.service.method(DEVICE, in_signature="", out_signature="", async_callbacks=("reply", "error"))
    def Connect(self, reply, error):
        self.server.control.perform(self, "device", True, reply, error)

    @dbus.service.method(DEVICE, in_signature="", out_signature="", async_callbacks=("reply", "error"))
    def Disconnect(self, reply, error):
        self.server.control.perform(self, "device", False, reply, error)

    @dbus.service.method(DEVICE, in_signature="", out_signature="")
    def Pair(self):
        self.server.control.forbidden.append(["Pair", self.path])


class Bluez(dbus.service.Object):
    def __init__(self, address, control):
        self.bus = dbus.bus.BusConnection(address)
        self.name = dbus.service.BusName("org.bluez", self.bus, do_not_queue=True)
        self.control = control
        super().__init__(self.bus, "/")
        self.objects = {}
        self.add_adapter("hci0")
        self.add_adapter("hci1")

    @dbus.service.method(OBJECTS, in_signature="", out_signature="a{oa{sa{sv}}}")
    def GetManagedObjects(self):
        self.control.reads += 1
        return {path: obj.interfaces for path, obj in self.objects.items()}

    @dbus.service.signal(OBJECTS, signature="oa{sa{sv}}")
    def InterfacesAdded(self, path, interfaces):
        pass

    @dbus.service.signal(OBJECTS, signature="oas")
    def InterfacesRemoved(self, path, interfaces):
        pass

    def add_adapter(self, id):
        path = "/org/bluez/" + id
        if path in self.objects:
            return
        props = dict(Alias=dbus.String("Test " + id), Powered=dbus.Boolean(True),
                     PowerState=dbus.String("on"), Discoverable=dbus.Boolean(False),
                     DiscoverableTimeout=dbus.UInt32(180), Discovering=dbus.Boolean(False),
                     Pairable=dbus.Boolean(True), PairableTimeout=dbus.UInt32(0))
        self.objects[path] = Adapter(self, path, {ADAPTER: props})
        self.InterfacesAdded(path, self.objects[path].interfaces)
        for suffix, name, paired in ([("01", "Headphones", True), ("02", "Keyboard", True), ("03", "Nearby", False)] if id == "hci0" else [("04", "Mouse", True)]):
            device_path = path + "/dev_00_11_22_33_44_" + suffix
            values = dict(Address=dbus.String("00:11:22:33:44:" + suffix),
                          Alias=dbus.String(name), Name=dbus.String(name),
                          Connected=dbus.Boolean(False), Paired=dbus.Boolean(paired),
                          Bonded=dbus.Boolean(paired), Trusted=dbus.Boolean(True),
                          Blocked=dbus.Boolean(False), WakeAllowed=dbus.Boolean(False),
                          Icon=dbus.String("audio-headphones"), Adapter=dbus.ObjectPath(path))
            interfaces = {DEVICE: values}
            if suffix == "01":
                interfaces[BATTERY] = {"Percentage": dbus.Byte(72)}
            self.objects[device_path] = Device(self, device_path, interfaces)
            self.InterfacesAdded(device_path, interfaces)

    def remove(self, path):
        for key in sorted(list(self.objects), reverse=True):
            if key == path or key.startswith(path + "/"):
                obj = self.objects.pop(key)
                self.InterfacesRemoved(key, list(obj.interfaces))
                obj.remove_from_connection()

    def close(self):
        self.bus.close()


class Control(dbus.service.Object):
    def __init__(self, bus, address):
        self.address = address
        self.reads, self.events, self.forbidden, self.held = 0, [], [], []
        self.mode = "ok"
        self.server = Bluez(address, self)
        self.name = dbus.service.BusName("org.putkin.BluetoothTest", bus, do_not_queue=True)
        super().__init__(bus, "/Test")

    def perform(self, obj, kind, value, reply, error):
        self.events.append([kind, obj.path, value])

        def finish():
            if self.mode == "deny":
                error(Rejected("test rejection"))
            else:
                if self.mode != "ignore" and obj.path in obj.server.objects:
                    if kind == "radio":
                        obj.update(ADAPTER, {"Powered": value, "PowerState": "on" if value else "off"})
                    else:
                        obj.update(DEVICE, {"Connected": value})
                reply()
            return False

        if self.mode == "hold":
            self.held.append(finish)
        else:
            GLib.timeout_add(40, finish)

    @dbus.service.method("org.putkin.BluetoothTest", in_signature="s", out_signature="s")
    def Command(self, payload):
        command = json.loads(str(payload))
        op = command["op"]
        if op == "mode":
            self.mode = command["value"]
        elif op == "release":
            self.mode = command.get("mode", "ok")
            held, self.held = self.held, []
            for finish in held:
                finish()
        elif op == "properties":
            self.server.objects[command["path"]].update(command["interface"], command["values"])
        elif op == "battery":
            obj = self.server.objects["/org/bluez/hci0/dev_00_11_22_33_44_01"]
            if command["value"] is None:
                obj.interfaces.pop(BATTERY, None)
                self.server.InterfacesRemoved(obj.path, [BATTERY])
            elif BATTERY in obj.interfaces:
                obj.update(BATTERY, {"Percentage": command["value"]})
            else:
                obj.interfaces[BATTERY] = {"Percentage": dbus.Byte(command["value"])}
                self.server.InterfacesAdded(obj.path, {BATTERY: obj.interfaces[BATTERY]})
        elif op == "remove":
            self.server.remove(command["path"])
        elif op == "adapter":
            self.server.add_adapter(command["id"])
        elif op == "owner":
            if command["value"] and self.server is None:
                self.server = Bluez(self.address, self)
            elif not command["value"] and self.server is not None:
                self.server.close()
                self.server = None
        elif op != "snapshot":
            raise ValueError(op)
        return json.dumps({"reads": self.reads, "events": self.events, "forbidden": self.forbidden, "held": len(self.held)})


if __name__ == "__main__":
    address = os.environ.get("DBUS_SYSTEM_BUS_ADDRESS", "")
    marker = Path(os.environ.get("PUTKIN_TEST_MARKER", "/nonexistent"))
    if not marker.is_file() or not str(marker).startswith("/tmp/pk-") or address != os.environ.get("DBUS_SESSION_BUS_ADDRESS") or address != f"unix:path={marker.parent}/bus":
        raise SystemExit("Refusing non-private D-Bus")
    DBusGMainLoop(set_as_default=True)
    connection = dbus.bus.BusConnection(address)
    control = Control(connection, address)
    GLib.MainLoop().run()
