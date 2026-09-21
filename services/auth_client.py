"""One private, ephemeral channel to the existing Putkin process. No secrets in IPC."""
import ctypes
import json
import os
from pathlib import Path
import resource
import signal
import socket
import stat
import struct
import subprocess
import tempfile
import time


class Cancelled(Exception):
    pass


def harden():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    if ctypes.CDLL(None).prctl(4, 0, 0, 0, 0) != 0:
        raise OSError("Cannot disable process dumps")
    def interrupted(_signum, _frame):
        raise Cancelled()
    for number in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(number, interrupted)


def request(payload, timeout=120):
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    info = runtime.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise OSError("Runtime directory is not private")
    data = json.dumps(payload, ensure_ascii=True).encode() + b"\n"
    if len(data) > 32768:
        raise ValueError("Request too large")
    config = os.environ.get("PUTKIN_AUTH_CONFIG") or str(Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "quickshell")
    with tempfile.TemporaryDirectory(prefix="putkin-auth-", dir=runtime) as directory:
        path = str(Path(directory) / "socket")
        with socket.socket(socket.AF_UNIX) as server:
            server.bind(path)
            os.chmod(path, 0o600)
            server.listen(1)
            server.settimeout(6)
            try:
                reply = subprocess.run(["qs", "ipc", "-p", config, "call", "authentication", "request", path],
                                       capture_output=True, text=True, timeout=6)
            except subprocess.TimeoutExpired as error:
                raise OSError("Putkin did not answer") from error
            if reply.returncode:
                raise OSError("Putkin unavailable")
            status = json.loads(reply.stdout)
            if status.get("accepted") is not True:
                raise Cancelled()
            peer, _ = server.accept()
            with peer:
                pid, uid, _ = struct.unpack("3i", peer.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
                if uid != os.getuid() or pid != status.get("pid"):
                    raise OSError("Unexpected peer")
                peer.settimeout(0.5)
                peer.sendall(data)
                expires = time.monotonic() + timeout if timeout else None
                parent = os.getppid()
                result = bytearray()
                try:
                    while b"\n" not in result:
                        if (expires and time.monotonic() >= expires) or os.getppid() != parent:
                            raise Cancelled()
                        try:
                            chunk = peer.recv(4096)
                        except socket.timeout:
                            continue
                        if not chunk:
                            raise Cancelled()
                        result.extend(chunk)
                        if len(result) > 32768:
                            raise ValueError("Response too large")
                    response = json.loads(result.split(b"\n", 1)[0])
                    if not isinstance(response.get("response"), str) or not isinstance(response.get("accepted"), bool):
                        raise ValueError("Invalid response")
                    return response
                except Cancelled:
                    try:
                        peer.sendall(b'{"closed":true}\n')
                        # Let Qt close its side after consuming cancellation.
                        # Closing both directions first causes PeerClosedError.
                        peer.recv(1)
                    except OSError:
                        pass
                    raise
                finally:
                    result[:] = b"\0" * len(result)
