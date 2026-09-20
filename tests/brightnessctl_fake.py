#!/usr/bin/env python3
"""Fake brightnessctl protocol. Only a private JSON fixture is read/written."""

import json
import os
from pathlib import Path
import signal
import sys
import time

fixture = Path(os.environ["PUTKIN_TEST_BACKLIGHT"])
assert fixture.is_absolute() and fixture.parent.name.startswith("pk-") and fixture.parent.parent == Path("/tmp")
assert (fixture.parent / "brightness-test-only").is_file()
events = fixture.with_suffix(".events")
args = sys.argv[1:]
setting = len(args) == 5 and args[2:4] == ["--quiet", "set"]
listing = args == ["--class=backlight", "--machine-readable", "--list"]
reading = len(args) == 4 and args[2:] == ["--machine-readable", "info"]
assert args[0] == "--class=backlight" and (setting or listing or reading), args
if not listing:
    assert args[1].startswith("--device="), args
with events.open("a") as stream:
    stream.write(json.dumps({"pid": os.getpid(), "time": time.monotonic(), "args": args}) + "\n")
state = json.loads(fixture.read_text())
mode = state.get("writeMode" if setting else "readMode", "ok")
if mode == "timeout":
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    time.sleep(30)
if mode == "crash":
    os.kill(os.getpid(), signal.SIGKILL)
time.sleep(state.get("delay", 0))
if mode == "denied":
    print("Can't modify brightness: Permission denied" if setting else "Error reading device: Permission denied", file=sys.stderr)
    sys.exit(1)
if mode == "malformed":
    print("test_backlight,backlight,30,30%,unknown")
    sys.exit(0)
devices = state["devices"]
if not listing:
    devices = [device for device in devices if device["device"] == args[1].split("=", 1)[1]]
if not devices:
    print("Failed to read any devices of class 'backlight'.", file=sys.stderr)
    sys.exit(1)
if setting:
    assert len(devices) == 1
    value = int(args[-1])
    assert 1 <= value <= devices[0]["maximum"], value
    if mode != "ignore":
        devices[0]["current"] = value
        fixture.write_text(json.dumps(state))
else:
    for device in devices:
        maximum = device.get("maximum", 0)
        percent = round(device["current"] * 100 / maximum) if maximum else 0
        print(f'{device["device"]},backlight,{device["current"]},{percent}%,{maximum}')
