#!/usr/bin/env python3
"""Private hyprsunset 0.4.0 IPC peer. No Wayland, D-Bus or hardware."""

import json
import os
from pathlib import Path
import socket
import sys
import time


def serve(path, fixture):
    path = Path(path)
    fixture = Path(fixture)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.unlink(missing_ok=True)
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
        server.bind(str(path))
        server.listen(10)
        while True:
            connection, _ = server.accept()
            with connection:
                command = connection.recv(1024).decode("ascii")
                if not command:
                    continue
                state = json.loads(fixture.read_text())
                with fixture.with_suffix(".events").open("a") as events:
                    events.write(json.dumps({"pid": os.getpid(), "command": command}) + "\n")
                writing = command.startswith("temperature ") or command == "identity true"
                mode = state.get("mode", "")
                if mode == "timeout" or (mode == "late" and writing):
                    time.sleep(0.6)
                if writing and mode == "denied":
                    response = "permission denied"
                elif writing:
                    if mode != "ignore":
                        state["enabled"] = command != "identity true"
                        if state["enabled"]:
                            state["temperature"] = int(command.split()[1])
                        fixture.write_text(json.dumps(state))
                    response = "ok"
                elif command == "identity get":
                    response = "false" if state["enabled"] else "true"
                elif command == "temperature":
                    response = str(state["temperature"])
                else:
                    response = "invalid command"
                if mode == "malformed":
                    response = "not a state"
                try:
                    if mode == "fragment":
                        for char in response:
                            connection.sendall(char.encode("ascii"))
                            time.sleep(0.003)
                    else:
                        connection.sendall(response.encode("ascii"))
                    while connection.recv(1024):
                        pass
                except (BrokenPipeError, ConnectionResetError):
                    pass


if __name__ == "__main__":
    serve(sys.argv[1], sys.argv[2])
