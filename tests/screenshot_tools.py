#!/usr/bin/python3
"""Finite executable fixtures; never connect to a display or clipboard."""
import json
import os
from pathlib import Path
import struct
import sys
import time
import zlib

root = Path(os.environ["PUTKIN_SCREENSHOT_FIXTURE"])
name = Path(sys.argv[0]).name
with (root / "calls").open("a") as log:
    log.write(json.dumps([name, *sys.argv[1:]]) + "\n")
config = json.loads((root / "fixture.json").read_text())
if name == "hyprctl":
    print(json.dumps(config[sys.argv[-1]]))
elif name == "grim":
    if config.get("slow"):
        (root / "grim.pid").write_text(str(os.getpid()))
        time.sleep(60)
    if config.get("captureError"):
        sys.exit(1)
    args = sys.argv
    scale = float(args[args.index("-s") + 1])
    if "-g" in args:
        width, height = map(int, args[args.index("-g") + 1].split()[1].split("x"))
        width, height = round(width * scale), round(height * scale)
    else:
        monitor = next(m for m in config["monitors"] if m["name"] == args[args.index("-o") + 1])
        width, height = monitor["width"], monitor["height"]
        if monitor.get("transform", 0) % 2:
            width, height = height, width
    def chunk(kind, value):
        return struct.pack(">I", len(value)) + kind + value + struct.pack(">I", zlib.crc32(kind + value))
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress((b"\0" + b"\x44\x66\x88" * width) * height)) + chunk(b"IEND", b"")
    Path(args[-1]).write_bytes(data)
elif name == "wl-copy":
    if config.get("clipboardError"):
        sys.exit(1)
    (root / "clipboard").write_bytes(sys.stdin.buffer.read())
else:
    sys.exit(2)
