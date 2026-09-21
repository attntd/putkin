"""Small private Hyprland IPC peer for testing the real Quickshell adapter."""

import json
import re
import socket
import threading
import time


class HyprlandPeer:
    def __init__(self, directory, lua=False, fragment_monitors=False):
        directory.mkdir(parents=True)
        self.lua = lua
        self.fragment_monitors = fragment_monitors
        self.fragmented_monitors = False
        self.monitors = [self.monitor(0, "TEST-1", 9, True), self.monitor(1, "TEST-2", 2, False)]
        self.workspaces = [dict(id=i, name=str(i), monitor="TEST-1" if i != 2 else "TEST-2",
                                windows=int(i == 12), hasfullscreen=False) for i in [2, 9, 12]]
        self.clients = [dict(address="0x123", workspace=dict(id=12, name="12"), monitor=0,
                             title="Test window", **{"class": "test"})]
        self.requests = []
        self.events = []
        self.failures = []
        self.stopped = threading.Event()
        self.listeners = []
        self.threads = []
        for name, handler in [(".socket.sock", self.request), (".socket2.sock", self.subscribe)]:
            server = socket.socket(socket.AF_UNIX)
            server.bind(str(directory / name))
            server.listen()
            server.settimeout(0.1)
            self.listeners.append(server)
            thread = threading.Thread(target=self.accept, args=(server, handler), daemon=True)
            thread.start()
            self.threads.append(thread)

    @staticmethod
    def monitor(identifier, name, workspace, focused):
        return dict(id=identifier, name=name, description=name, width=1920, height=1080,
                    x=identifier * 1920, y=0, scale=1, focused=focused,
                    activeWorkspace=dict(id=workspace, name=str(workspace)))

    def accept(self, server, handler):
        while not self.stopped.is_set():
            try:
                connection, _ = server.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            try:
                handler(connection)
            except Exception as error:
                self.failures.append(repr(error))
                connection.close()

    def subscribe(self, connection):
        self.events.append(connection)

    def send(self, event):
        for connection in list(self.events):
            try:
                connection.sendall((event + "\n").encode())
            except OSError:
                self.events.remove(connection)
                connection.close()

    def request(self, connection):
        with connection:
            connection.settimeout(2)
            request = connection.recv(65536).decode()
            self.requests.append(request)
            responses = {"j/status": {"configProvider": "lua" if self.lua else "hyprlang"},
                         "j/monitors": self.monitors, "j/workspaces": self.workspaces, "j/clients": self.clients}
            if request in responses:
                response = json.dumps(responses[request]).encode()
                if request == "j/monitors" and self.fragment_monitors and not self.fragmented_monitors:
                    self.fragmented_monitors = True
                    # AF_UNIX is a byte stream: one readyRead need not contain
                    # the complete JSON response. Quickshell 0.3.1 closes early.
                    connection.sendall(response[:len(response) // 2])
                    time.sleep(0.05)
                    try:
                        connection.sendall(response[len(response) // 2:])
                    except BrokenPipeError:
                        pass
                else:
                    connection.sendall(response)
                return
            focus = re.fullmatch(r'dispatch hl\.dsp\.focus\(\{ monitor = "(\d+)" \}\)', request) if self.lua else re.fullmatch(r"dispatch focusmonitor (\d+)", request)
            activate = re.fullmatch(r'dispatch hl\.dsp\.focus\(\{ workspace = "(\d+)", on_current_monitor = true \}\)', request) if self.lua else re.fullmatch(r"dispatch focusworkspaceoncurrentmonitor (\d+)", request)
            move = re.fullmatch(r'dispatch hl\.dsp\.window\.move\(\{ workspace = "(\d+)", follow = false, window = "address:(0x[0-9a-fA-F]+)" \}\)', request) if self.lua else re.fullmatch(r"dispatch movetoworkspacesilent (\d+),address:(0x[0-9a-fA-F]+)", request)
            if focus:
                identifier = int(focus[1])
                for monitor in self.monitors:
                    monitor["focused"] = monitor["id"] == identifier
                monitor = next(m for m in self.monitors if m["focused"])
                connection.sendall(b"ok")
                self.send(f"focusedmon>>{monitor['name']},{monitor['activeWorkspace']['name']}")
            elif activate:
                identifier = int(activate[1])
                monitor = next(m for m in self.monitors if m["focused"])
                monitor["activeWorkspace"] = dict(id=identifier, name=str(identifier))
                self.ensure_workspace(identifier, monitor["name"])
                connection.sendall(b"ok")
                self.send(f"moveworkspacev2>>{identifier},{identifier},{monitor['name']}")
                self.send(f"workspacev2>>{identifier},{identifier}")
            elif move:
                identifier, address = int(move[1]), move[2]
                window = next(client for client in self.clients if client["address"] == address)
                monitor = next(m for m in self.monitors if m["id"] == window["monitor"])
                self.ensure_workspace(identifier, monitor["name"])
                window["workspace"] = dict(id=identifier, name=str(identifier))
                connection.sendall(b"ok")
                self.send(f"movewindowv2>>{address.removeprefix('0x')},{identifier},{identifier}")
            else:
                self.failures.append(f"Unexpected request: {request}")
                connection.sendall(b"unknown request")

    def ensure_workspace(self, identifier, monitor):
        if not any(workspace["id"] == identifier for workspace in self.workspaces):
            self.workspaces.append(dict(id=identifier, name=str(identifier), monitor=monitor,
                                        windows=0, hasfullscreen=False))
            self.send(f"createworkspacev2>>{identifier},{identifier}")

    def disconnect(self):
        for connection in self.events:
            connection.shutdown(socket.SHUT_RDWR)
            connection.close()
        self.events.clear()

    def close(self):
        self.stopped.set()
        self.disconnect()
        for server in self.listeners:
            server.close()
        for thread in self.threads:
            thread.join(timeout=3)
