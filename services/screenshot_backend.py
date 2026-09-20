#!/usr/bin/env python3
"""One confirmed screenshot; no process or image during selection.

The private PNG lives until preview dismissal. wl-copy owns its independent
clipboard bytes. Only explicit save creates a persistent file.
"""
from datetime import datetime
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import struct
import subprocess
import sys
import tempfile


def emit(kind, **values):
    print(json.dumps({"type": kind, **values}, ensure_ascii=False), flush=True)


def run(command, **kwargs):
    result = subprocess.run(command, stderr=subprocess.PIPE, timeout=10, **kwargs)
    if result.returncode:
        raise ValueError(f"{command[0]}: " + result.stderr.decode(errors="replace").strip()[:300])
    return result


def hypr(kind):
    return json.loads(run(["hyprctl", "-j", kind], stdout=subprocess.PIPE).stdout)


def monitor_geometry(monitor):
    scale = float(monitor["scale"])
    if not math.isfinite(scale) or not 0.25 <= scale <= 8:
        raise ValueError("Niepoprawna skala monitora.")
    width, height = monitor["width"], monitor["height"]
    if monitor.get("transform", 0) % 2:
        width, height = height, width
    return monitor["x"], monitor["y"], round(width / scale), round(height / scale), scale


def geometry(request, monitors, clients):
    monitor = next((item for item in monitors if item["name"] == request["screen"]), None)
    if not monitor or monitor.get("disabled") or monitor.get("dpmsStatus") is False:
        raise ValueError("Monitor jest niedostępny.")
    x, y, width, height, scale = monitor_geometry(monitor)
    mode = request["mode"]
    if mode == "region":
        left, top, w, h = request["region"]
        if any(type(v) not in (int, float) or not math.isfinite(v) for v in (left, top, w, h)):
            raise ValueError("Niepoprawny zakres zrzutu.")
        right, bottom = min(width, math.ceil(left + w)), min(height, math.ceil(top + h))
        left, top = max(0, math.floor(left)), max(0, math.floor(top))
        x, y, width, height = x + left, y + top, right - left, bottom - top
    elif mode == "window":
        address = request.get("window", "").removeprefix("0x").lower()
        if not re.fullmatch(r"[0-9a-f]{1,16}", address):
            raise ValueError("Niepoprawny identyfikator okna.")
        window = next((item for item in clients if item["address"].removeprefix("0x").lower() == address), None)
        visible = {m.get("activeWorkspace", {}).get("id") for m in monitors}
        visible.update(m.get("specialWorkspace", {}).get("id") for m in monitors if m.get("specialWorkspace", {}).get("id"))
        if not window or not window.get("mapped") or window.get("hidden") or (not window.get("pinned") and window["workspace"]["id"] not in visible):
            raise ValueError("Okno sprzed uruchomienia zrzutu jest niedostępne.")
        wx, wy = window["at"]
        ww, wh = window["size"]
        # Retain the whole visible window, including parts on other outputs.
        intersections = []
        for item in monitors:
            if item.get("disabled") or item.get("dpmsStatus") is False:
                continue
            mx, my, mw, mh, ms = monitor_geometry(item)
            left, top = max(wx, mx), max(wy, my)
            right, bottom = min(wx + ww, mx + mw), min(wy + wh, my + mh)
            if right > left and bottom > top:
                intersections.append((left, top, right, bottom, ms))
        if not intersections:
            raise ValueError("Okno znajduje się poza widocznymi ekranami.")
        x, y = min(r[0] for r in intersections), min(r[1] for r in intersections)
        width, height = max(r[2] for r in intersections) - x, max(r[3] for r in intersections) - y
        scale = max(r[4] for r in intersections)
    elif mode != "screen":
        raise ValueError("Nieznany rodzaj zrzutu.")
    if width <= 0 or height <= 0:
        raise ValueError("Zakres zrzutu jest pusty.")
    return f"{int(x)},{int(y)} {int(width)}x{int(height)}", scale


def save_image(source, pictures):
    directory = Path(pictures)
    if not directory.is_absolute():
        raise ValueError("Katalog obrazów jest niedostępny.")
    directory = directory / "Screenshots"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S-%f")
    # mkstemp reserves a unique name without ever overwriting a user's file.
    fd, name = tempfile.mkstemp(prefix=f"Screenshot_{stamp}_", suffix=".png", dir=directory)
    try:
        with os.fdopen(fd, "wb") as target, source.open("rb") as origin:
            shutil.copyfileobj(origin, target)
            target.flush()
            os.fsync(target.fileno())
    except BaseException:
        Path(name).unlink(missing_ok=True)
        raise
    return name


def session(request):
    monitors = hypr("monitors")
    region, scale = geometry(request, monitors, hypr("clients") if request["mode"] == "window" else [])
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    with tempfile.TemporaryDirectory(prefix="putkin-screenshot-", dir=runtime) as directory:
        path = Path(directory) / "capture.png"
        target = ["-o", request["screen"]] if request["mode"] == "screen" else ["-g", region]
        run(["grim", "-t", "png", "-l", "1", "-s", str(scale), *target, str(path)], stdout=subprocess.DEVNULL)
        path.chmod(0o600)
        with path.open("rb") as source:
            header = source.read(24)
        if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError("Przechwycenie nie zwróciło obrazu PNG.")
        width, height = struct.unpack(">II", header[16:24])
        copy_error = ""
        try:
            # wl-copy forks after reading stdin. Its child must not hold our
            # JSON stdout/stderr pipes open, and survives closing this preview.
            with path.open("rb") as source, tempfile.TemporaryFile() as errors:
                result = subprocess.run(["wl-copy", "--type", "image/png"], stdin=source,
                                        stdout=subprocess.DEVNULL, stderr=errors, timeout=5)
                if result.returncode:
                    raise ValueError("Schowek odrzucił obraz.")
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            copy_error = "Nie skopiowano zrzutu do schowka: " + str(error)
        emit("captured", source=path.as_uri(), width=width, height=height, error=copy_error)
        for line in sys.stdin:
            try:
                message = json.loads(line)
                if message.get("op") == "save":
                    emit("saved", path=save_image(path, request["pictures"]))
                elif message.get("op") == "close":
                    break
            except (OSError, ValueError, KeyError) as error:
                emit("error", error="Nie zapisano zrzutu: " + str(error))


def terminate(_signum, _frame):
    raise SystemExit(0)


def main():
    os.umask(0o077)
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    try:
        line = sys.stdin.readline(65537)
        if not line:
            return 0
        if len(line) > 65536:
            raise ValueError("Zbyt duże żądanie zrzutu.")
        session(json.loads(line))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        emit("error", error="Nie wykonano zrzutu: " + str(error), fatal=True)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
