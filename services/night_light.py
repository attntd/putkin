#!/usr/bin/env python3
"""One bounded transaction with the existing hyprsunset 0.4.0 user service.

Never starts/stops a service. The private socket belongs to the selected
Hyprland instance. identity get is NOT safe on old hyprsunset releases, so
verify the running executable and version before sending any IPC.
"""

import ctypes
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import struct
import subprocess
import sys


class Unavailable(Exception):
    pass


def bounded_command(arguments):
    # This helper is single-threaded. Its short-lived children must also die
    # on QML reload/SIGKILL, when Python's communicate timeout cannot run.
    parent = os.getpid()
    libc = ctypes.CDLL(None, use_errno=True)

    def tie_to_parent():
        if libc.prctl(1, signal.SIGKILL, 0, 0, 0) != 0 or os.getppid() != parent:
            os._exit(127)

    return subprocess.run(arguments, capture_output=True, text=True, timeout=0.8,
                          check=False, preexec_fn=tie_to_parent)


def process_token(pid):
    # starttime survives neither a restart nor PID reuse; comm can contain spaces.
    fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
    return f"{pid}:{fields[19]}"


def inspect_owner(pid):
    executable = shutil.which("hyprsunset")
    if not executable:
        raise Unavailable("absent")
    if not os.path.samefile(executable, f"/proc/{pid}/exe"):
        raise Unavailable("owner")
    result = bounded_command(["systemctl", "--user", "show", "hyprsunset.service", "--property=MainPID", "--property=ActiveState"])
    values = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    if result.returncode or values.get("ActiveState") != "active" or values.get("MainPID") != str(pid):
        raise Unavailable("service")
    version = bounded_command([executable, "--version"])
    if version.returncode or not re.search(r"\bhyprsunset v0\.4\.0\b", version.stdout):
        raise Unavailable("version")
    # A package replacement or service restart during preflight invalidates it.
    if not os.path.samefile(executable, f"/proc/{pid}/exe"):
        raise Unavailable("owner")


def socket_path():
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    instance = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not os.path.isabs(runtime) or not re.fullmatch(r"[A-Za-z0-9_-]+", instance):
        raise Unavailable("session")
    return Path(runtime) / "hypr" / instance / ".hyprsunset.sock"


class Client:
    def __init__(self, path, owner_check=inspect_owner, timeout=0.35):
        self.path = path
        self.owner_check = owner_check
        self.timeout = timeout
        self.owner = None

    def connect(self):
        connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            connection.settimeout(self.timeout)
            connection.connect(str(self.path))
            pid, uid, _ = struct.unpack("3i", connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
            if uid != os.getuid():
                raise Unavailable("owner")
            token = process_token(pid)
            if self.owner is None:
                self.owner_check(pid)
                if token != process_token(pid):
                    raise Unavailable("restart")
                self.owner = token
            elif token != self.owner:
                raise Unavailable("restart")
            return connection
        except BaseException:
            connection.close()
            raise

    def request(self, command):
        with self.connect() as connection:
            connection.sendall(command.encode("ascii"))
            # The server has no response framing. EOF after half-close gives
            # the complete reply, including fragmented stream packets.
            connection.shutdown(socket.SHUT_WR)
            response = bytearray()
            while True:
                chunk = connection.recv(1024)
                if not chunk:
                    break
                response.extend(chunk)
                if len(response) > 1024:
                    raise Unavailable("protocol")
            return response.decode("ascii").strip()

    def snapshot(self):
        before = self.request("identity get")
        temperature = self.request("temperature")
        after = self.request("identity get")
        if before not in ("true", "false") or before != after or not re.fullmatch(r"[0-9]{4,5}", temperature):
            raise Unavailable("protocol")
        kelvin = int(temperature)
        if not 1000 <= kelvin <= 20000:
            raise Unavailable("protocol")
        return {"owner": self.owner, "enabled": after == "false", "temperature": kelvin}

    def execute(self, arguments):
        if arguments == ["read"]:
            return self.snapshot()
        if len(arguments) != 4 or arguments[0] != "set" or arguments[2] not in ("on", "off"):
            raise Unavailable("input")
        if not re.fullmatch(r"[0-9]+:[0-9]+", arguments[1]) or not re.fullmatch(r"[0-9]{4}", arguments[3]):
            raise Unavailable("input")
        temperature = int(arguments[3])
        if not 1000 <= temperature <= 6500:
            raise Unavailable("input")
        # Read-only preflight; never replay an old intent into a restarted daemon.
        current = self.snapshot()
        if current["owner"] != arguments[1]:
            raise Unavailable("restart")
        enabled = arguments[2] == "on"
        command = f"temperature {temperature}" if enabled else "identity true"
        if self.request(command) != "ok":
            raise Unavailable("denied")
        confirmed = self.snapshot()
        if confirmed["enabled"] != enabled or (enabled and confirmed["temperature"] != temperature):
            raise Unavailable("unconfirmed")
        return confirmed


def run(arguments, client=None):
    try:
        return {"sample": (client or Client(socket_path())).execute(arguments), "error": ""}
    except Unavailable as error:
        return {"sample": None, "error": str(error)}
    except (TimeoutError, subprocess.TimeoutExpired):
        return {"sample": None, "error": "timeout"}
    except PermissionError:
        return {"sample": None, "error": "denied"}
    except (FileNotFoundError, ConnectionRefusedError, ProcessLookupError):
        return {"sample": None, "error": "absent"}
    except (OSError, ValueError, UnicodeError):
        return {"sample": None, "error": "protocol"}


if __name__ == "__main__":
    print(json.dumps(run(sys.argv[1:])), flush=True)
