"""Resolve the pinned optional calling component without changing the CLI/JRE pin."""
import json
import os
from pathlib import Path
import shutil

from signal_release import digest, ROOT


def verify(bundle, source=ROOT):
    pin = json.loads((source / "services/signal-call-tunnel/runtime.json").read_text())
    record = json.loads((bundle / "manifest.json").read_text())
    binary = bundle / "bin/signal-call-tunnel"
    if (not isinstance(record, dict) or record.get("format") != 1 or record.get("source") != pin
            or bundle.is_symlink() or (bundle / "manifest.json").is_symlink() or (bundle / "bin").is_symlink()
            or binary.is_symlink() or not binary.is_file()
            or not os.access(binary, os.X_OK) or digest(binary) != record.get("sha256")):
        raise ValueError("Nieprawidłowy tunel rozmów Signal. Uruchom scripts/prepare-signal-calls.")
    return binary


def resolve(source=ROOT):
    for bundle in (source / "dependencies/signal-calls", source / "artifacts/signal-call-runtime"):
        if bundle.exists():
            try:
                return str(verify(bundle, source))
            except (OSError, ValueError, KeyError):
                return None
    return None


def configure(env):
    binary = resolve()
    # Never inherit an unrelated tunnel from the desktop environment/PATH.
    env.pop("SIGNAL_CALL_TUNNEL_BIN", None)
    if binary and shutil.which("pactl") and shutil.which("pacat"):
        env["SIGNAL_CALL_TUNNEL_BIN"] = binary
        return True
    return False
