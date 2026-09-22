"""Signal-specific installer checks. No protocol, history or media backups."""
from contextlib import contextmanager
import ctypes
import fcntl
import json
import os
import platform
from pathlib import Path
import shutil
import sqlite3
import stat
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services"))
from signal_release import compatibility, release_spec, safe_path, verify_runtime
from _signal_bootstrap import build, bundle_path


def runtime(source, supplied=None, *, prepare=False, dry_run=False, cache=None, offline=False, installed=None):
    if release_spec(source) is None:
        if supplied:
            raise ValueError("Źródła nie zawierają integracji Signala.")
        return None, None
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise ValueError("Runtime Signala wymaga Linux x86_64/glibc.")
    candidates = [source / "dependencies/signal", bundle_path(source, cache), ROOT / "artifacts/signal-runtime"]
    if installed:
        candidates.append(installed / "dependencies/signal")
    bundle = supplied
    if bundle is None:
        for candidate in candidates:
            if candidate.is_dir():
                try:
                    verify_runtime(candidate, source)
                except ValueError:
                    if installed and candidate == installed / "dependencies/signal":
                        continue  # An earlier release can have a different pin.
                    raise
                bundle = candidate
                break
    pin = json.loads((source / "services/signal-cli-media/distribution.json").read_text())
    info = {key: pin[key] for key in ("platform", "cliVersion", "javaVersion", "policy", "treeSha256")}
    if bundle is not None:
        info = verify_runtime(bundle, source)
    elif dry_run:
        info["action"] = "build-from-cache" if offline else "download-patch-build"
    elif prepare:
        bundle = build(source, cache, offline)
        info = verify_runtime(bundle, source)
    else:
        raise ValueError("Brak runtime Signala. scripts/install przygotuje go automatycznie; osobno: scripts/prepare-signal.")
    missing = [name for name in ("ffmpeg", "ffprobe", "file") if not shutil.which(name)]
    try:
        ctypes.CDLL("libqrencode.so.4")
    except OSError:
        missing.append("libqrencode.so.4")
    if missing:
        raise ValueError("Brak zależności Signala: " + ", ".join(missing))
    return bundle, info


def inspect(layout, source):
    try:
        return compatibility(layout["store"] / "signal", release_spec(source))
    except sqlite3.Error:
        raise ValueError("Nie można odczytać historii Signala; przełączenie zatrzymane przed zmianą danych.") from None


@contextmanager
def handoff(layout, source):
    """Recheck data after stop while excluding any other Signal receiver."""
    path = layout["store"] / "signal/owner.lock"
    safe_path(path)
    fd = None
    try:
        if path.exists():
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
                raise ValueError("Nieprawidłowa blokada danych Signala.")
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise RuntimeError("Proces Signala nadal używa danych; przełączenie zatrzymane.") from None
        inspect(layout, source)
        yield
    finally:
        if fd is not None:
            os.close(fd)
