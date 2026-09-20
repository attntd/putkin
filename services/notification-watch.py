#!/usr/bin/env python3
"""Bounded replacement metadata for Quickshell 0.3.1; never a notification server.

The native API omits identical replacements and changes to action labels.
Images and message bodies must not enter a JSON stream/the QML JS heap.
"""
import json
import sys

sys.dont_write_bytecode = True


def main():
    import dbus
    from dbus.mainloop.glib import DBusGMainLoop
    from gi.repository import GLib

    DBusGMainLoop(set_as_default=True)
    bus = dbus.bus.BusConnection(dbus.bus.BUS_SESSION)
    loop = GLib.MainLoop()

    def emit(value):
        print(json.dumps(value, ensure_ascii=True, separators=(",", ":")), flush=True)

    def message(_connection, value):
        try:
            member = value.get_member()
            if member == "NameOwnerChanged" and value.get_sender() == "org.freedesktop.DBus":
                args = value.get_args_list()
                emit({"owner": str(args[2])})
            elif member == "Notify" and value.get_signature() == "susssasa{sv}i":
                # byte_arrays prevents millions of Python int objects for an
                # image. No body, image, app name or hints are copied to stdout.
                args = value.get_args_list(byte_arrays=True)
                if int(args[1]) > 0:
                    actions = []
                    for index in range(0, min(len(args[5]) - 1, 16), 2):
                        identifier = str(args[5][index])
                        if len(identifier) <= 256:
                            actions.extend((identifier, str(args[5][index + 1])[:128]))
                    emit({"id": int(args[1]), "destination": value.get_destination(),
                          "actions": actions, "timeout": int(args[7])})
        except Exception:
            # Even exceptional diagnostics must never include sender data.
            print("Notification observer could not decode a message.", file=sys.stderr, flush=True)
            loop.quit()
        return dbus.lowlevel.HANDLER_RESULT_HANDLED

    bus.add_message_filter(message)
    bus.call_on_disconnection(lambda _connection: loop.quit())
    bus.call_blocking("org.freedesktop.DBus", "/org/freedesktop/DBus",
        "org.freedesktop.DBus.Monitoring", "BecomeMonitor", "asu", [
            ["type='method_call',interface='org.freedesktop.Notifications',member='Notify',path='/org/freedesktop/Notifications'",
             "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.freedesktop.Notifications'"], 0], timeout=2)
    emit({"ready": True})
    loop.run()
    bus.close()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Notification observer unavailable (python-dbus, python-gobject or session D-Bus).", file=sys.stderr)
        sys.exit(1)
