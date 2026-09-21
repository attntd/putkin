"""Offline test owner using the production exec shim, lease and transport."""
import asyncio
import json
import os
from pathlib import Path
import signal
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "services"))
from signal_backend import StoreLease, directory
from signal_transport import RpcTransport, spawn


async def main():
    os.umask(0o077)
    lease = StoreLease()
    assert lease.acquire()
    cli_dir = lease.data / "cli"
    os.close(directory(cli_dir, private=True))
    child = await spawn([sys.argv[1], "--data-dir", str(cli_dir), "--scrub-log", "jsonRpc", "--receive-mode", "manual"], lease.lock_fd)
    print(json.dumps({"phase": "spawned", "pid": child.pid}), flush=True)
    transport = RpcTransport(child, lambda _: None)
    stop = asyncio.Event()
    lease_released = False
    asyncio.get_running_loop().add_signal_handler(signal.SIGTERM, stop.set)
    try:
        assert await transport.request("listAccounts", timeout=20) == []
        subscription = await transport.request("subscribeReceive") if os.environ.get("PUTKIN_SIGNAL_MEASURE") else None
        inode = os.fstat(lease.lock_fd).st_ino
        inherited = any(fd.stat().st_ino == inode for fd in Path(f"/proc/{child.pid}/fd").iterdir() if fd.exists())
        # Deliberately release the test owner's FD: external flock must still
        # fail while the JVM alone owns the inherited open file description.
        lease.close()
        lease_released = True
        print(json.dumps({"phase": "ready", "pid": child.pid, "lockInherited": inherited,
                          "executable": Path(f"/proc/{child.pid}/exe").resolve().name,
                          "subscriptionCount": int(subscription is not None)}), flush=True)
        await stop.wait()
    finally:
        await transport.close()
        if not lease_released:
            lease.close()


if __name__ == "__main__":
    asyncio.run(main())
