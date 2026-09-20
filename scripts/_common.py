"""Small helpers shared by the stage 00 developer commands (Python stdlib only)."""

import os
import json
from pathlib import Path
import shutil
import signal
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def runtime_log(log):
    """Read a running child's log without moving its shared file offset."""
    if isinstance(log, list):
        return "\n".join(f"{name}:\n{runtime_log(stream)}" for name, stream in log)
    return os.pread(log.fileno(), os.fstat(log.fileno()).st_size, 0).decode("utf-8", errors="replace")


def ipc_reply(result, process, log, *, starting=False):
    """Keep the QML cause of failed startup/reload ahead of IPC/JSON errors.

    Deliberate service errors are checked by each integration's own allowlist.
    A failed reload is fatal even when Quickshell keeps the old graph alive.
    """
    output = runtime_log(log)
    failed_load = any(token in output for token in (
        "Failed to load configuration", "Failed to reload configuration",
        "Failed to load root component", "Failed to reload config",
    ))
    if failed_load or process.poll() is not None:
        raise AssertionError(f"Quickshell startup/reload failed (exit={process.poll()}):\n{output}")
    if result.returncode:
        if starting:
            return ""
        raise AssertionError(f"IPC failed (exit={result.returncode}): {result.stderr}\n{result.stdout}\n{output}")
    return result.stdout.strip()


def ipc_json(value):
    """Only an absent startup reply is retryable; malformed replies fail."""
    if not value:
        return {}
    try:
        result = json.loads(value)
    except json.JSONDecodeError as error:
        raise AssertionError(f"Invalid IPC JSON reply: {value!r}") from error
    if not isinstance(result, dict):
        raise AssertionError(f"Expected an IPC object, received: {value!r}")
    return result


def tool(name):
    override = os.environ.get("PUTKIN_" + name.upper())
    candidates = [override] if override is not None else [
        shutil.which(name),
        f"/usr/lib/qt6/bin/{name}",
        f"/usr/lib64/qt6/bin/{name}",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return str(Path(candidate).resolve())
    raise FileNotFoundError(f"Brak narzędzia {name}; ustaw PUTKIN_{name.upper()} lub zainstaluj wymagany pakiet.")


def isolated_environment(directory):
    """No inherited display, session, import paths or hardware service addresses."""
    base = Path(directory)
    env = {
        "PATH": "/usr/bin:/bin:/usr/lib/qt6/bin",
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
        "TZ": "UTC",
        "QT_QPA_PLATFORM": "offscreen",
        "QT_QUICK_BACKEND": "software",
        "QSG_RENDER_LOOP": "basic",
        "QT_QUICK_CONTROLS_STYLE": "Basic",
        "QT_SCALE_FACTOR": "1",
        "NO_COLOR": "1",
        "DBUS_SESSION_BUS_ADDRESS": f"unix:path={base}/no-session-bus",
        "DBUS_SYSTEM_BUS_ADDRESS": f"unix:path={base}/no-system-bus",
        "PIPEWIRE_REMOTE": str(base / "no-pipewire"),
        "PULSE_SERVER": f"unix:{base}/no-pulse",
    }
    for kind in ["config", "cache", "data", "state", "runtime"]:
        path = base / kind
        path.mkdir(mode=0o700)
        env[f"XDG_{kind.upper()}_{'DIR' if kind == 'runtime' else 'HOME'}"] = str(path)
    env["XDG_CONFIG_DIRS"] = env["XDG_CONFIG_HOME"]
    env["XDG_DATA_DIRS"] = env["XDG_DATA_HOME"]
    return env


def stop_process_group(process):
    """Stop only the private process group started by this invocation."""
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)


def qml_errors(log, allow_offscreen_masks=False):
    return [line for line in log.splitlines() if any(token in line for token in (
        "WARN", "ERROR", "QWARN", "QFATAL", "ReferenceError:", "TypeError:",
        "SyntaxError:", "Failed to load", "is not installed", "PUTKIN_SCREENSHOT_FAILED",
    )) and not (allow_offscreen_masks and line.strip() == "WARN: This plugin does not support setting window masks")]
