#!/usr/bin/python3
"""Private authority; records outcomes, never grants host privileges."""
import json
import os
from pathlib import Path
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

AUTHORITY = 'org.freedesktop.PolicyKit1.Authority'
CONTROL = 'org.putkin.AuthenticationFixture'


class Authority(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, '/org/freedesktop/PolicyKit1/Authority')
        self.bus = bus
        self.peer = None
        self.path = None
        self.outcomes = []
        self.number = 0

    @dbus.service.method(AUTHORITY, in_signature='(sa{sv})so', out_signature='', sender_keyword='sender')
    def RegisterAuthenticationAgent(self, subject, locale, path, sender=None):
        assert str(subject[0]) == 'unix-session'
        self.peer, self.path = sender, path

    @dbus.service.method(AUTHORITY, in_signature='(sa{sv})soa{sv}', out_signature='', sender_keyword='sender')
    def RegisterAuthenticationAgentWithOptions(self, subject, locale, path, options, sender=None):
        self.RegisterAuthenticationAgent(subject, locale, path, sender)

    @dbus.service.method(AUTHORITY, in_signature='(sa{sv})o', out_signature='')
    def UnregisterAuthenticationAgent(self, subject, path):
        self.peer = None

    @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='s', out_signature='a{sv}')
    def GetAll(self, interface):
        return {'BackendName': 'fixture', 'BackendVersion': '1', 'BackendFeatures': dbus.UInt32(0)}

    @dbus.service.method(CONTROL, in_signature='s', out_signature='')
    def Begin(self, mode):
        self.number += 1
        cookie = str(mode) + '-' + str(self.number)
        obj = self.bus.get_object(self.peer, self.path)
        obj.BeginAuthentication('org.putkin.fixture', 'Fixture application — operation', '',
            dbus.Dictionary({}, signature='ss'), cookie,
            dbus.Array([dbus.Struct(('unix-user', dbus.Dictionary({'uid': dbus.UInt32(os.getuid())}, signature='sv')), signature='sa{sv}')], signature='(sa{sv})'),
            dbus_interface='org.freedesktop.PolicyKit1.AuthenticationAgent',
            reply_handler=lambda: self.outcomes.append([cookie, 'complete']),
            error_handler=lambda error: self.outcomes.append([cookie, error.get_dbus_name()]))

    @dbus.service.method(CONTROL, in_signature='', out_signature='s')
    def Snapshot(self):
        return json.dumps({'registered': bool(self.peer), 'outcomes': self.outcomes})


DBusGMainLoop(set_as_default=True)
base = Path(os.environ['PUTKIN_AUTHENTICATION_TEST'])
assert Path('/proc/1/comm').read_text().strip() == 'bwrap'
assert (base / 'authentication-fixture').is_file()
assert os.environ['DBUS_SYSTEM_BUS_ADDRESS'] == os.environ['DBUS_SESSION_BUS_ADDRESS'] == 'unix:path=' + str(base / 'auth-bus')
bus = dbus.SessionBus()
name = dbus.service.BusName('org.freedesktop.PolicyKit1', bus, do_not_queue=True)
authority = Authority(bus)
GLib.MainLoop().run()
