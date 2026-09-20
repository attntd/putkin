"""Small immutable runtime store. Only current is the publication boundary."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
KEEP = 5
MARKER = ".putkin-build.json"
BUILD_NAME = re.compile(r"[0-9]{8}-(?:[a-z0-9-]+-)?[0-9a-f]{12}")
RUNTIME_DIRS = ("assets", "components", "config", "core", "modules", "services")


def paths(destination=None):
    if destination:
        base = Path(destination).absolute()
        config, data, state, binary = (base / p for p in ("config", "data", "state", "bin"))
    else:
        base = Path.home()
        config = Path(os.environ.get("XDG_CONFIG_HOME") or base / ".config")
        data = Path(os.environ.get("XDG_DATA_HOME") or base / ".local/share")
        state = Path(os.environ.get("XDG_STATE_HOME") or base / ".local/state")
        binary = base / ".local/bin"
    return {"store": data / "putkin", "state": state / "putkin",
            "entry": config / "quickshell/shell.qml", "launcher": binary / "qs"}


def manifest(root):
    result = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if "__pycache__" in relative.parts or path.suffix == ".pyc" or str(relative) == MARKER:
            continue
        if path.is_symlink():
            raise ValueError(f"Dowiązanie w paczce runtime: {relative}")
        if path.is_file():
            result[str(relative)] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def source_files(root):
    selected = [root / "shell.qml", root / "scripts/lock-session"]
    for directory in RUNTIME_DIRS:
        base = root / directory
        if not base.is_dir() or base.is_symlink():
            raise ValueError(f"Brak katalogu runtime: {base}")
        for path in base.rglob("*"):
            if "__pycache__" in path.parts or path.suffix == ".pyc":
                continue
            if path.is_symlink():
                raise ValueError(f"Dowiązanie w źródłach runtime: {path}")
            if path.is_file():
                selected.append(path)
    for path in selected:
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Nieprawidłowy plik runtime: {path}")
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in selected}


def atomic_file(path, data, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".putkin-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def atomic_link(path, target):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".link-", dir=path.parent) as directory:
        link = Path(directory) / "link"
        link.symlink_to(target)
        os.replace(link, path)


def current(store, name="current"):
    link = store / name
    if not link.is_symlink():
        if link.exists():
            raise ValueError(f"Oczekiwano dowiązania: {link}")
        return None
    target = link.resolve(strict=True)
    if target.parent != (store / "releases").resolve() or not target.is_dir():
        raise ValueError(f"Obce wskazanie: {link}")
    return target


def releases(store):
    directory = store / "releases"
    if not directory.exists():
        return []
    # Existing local builds use the same dated names. Never follow directory links.
    return sorted((p for p in directory.iterdir() if not p.is_symlink() and p.is_dir()
                   and BUILD_NAME.fullmatch(p.name) and (p / "shell.qml").is_file()),
                  key=lambda p: (p.stat().st_mtime_ns, p.name), reverse=True)


def verify(build):
    record = json.loads((build / MARKER).read_text())
    if record.get("format") != 1 or manifest(build) != record.get("files"):
        raise ValueError(f"Uszkodzona paczka: {build}")


def validate(stage):
    subprocess.run([str(ROOT / "scripts/check"), str(stage)], check=True)
    for path in stage.rglob("*.py"):
        compile(path.read_bytes(), str(path), "exec")


def prepare(store, source=ROOT):
    expected = source_files(source)
    for build in releases(store):
        if manifest(build) == expected:
            validate(build)
            atomic_file(build / MARKER, json.dumps({"format": 1, "files": expected}, sort_keys=True).encode())
            return build
    directory = store / "releases"
    directory.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(json.dumps(expected, sort_keys=True).encode()).hexdigest()[:12]
    name = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S") + "-" + digest
    build = directory / name
    with tempfile.TemporaryDirectory(prefix=".stage-", dir=directory) as temporary:
        stage = Path(temporary) / "runtime"
        stage.mkdir()
        for relative in expected:
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / relative, target)
        if manifest(stage) != expected:
            raise ValueError("Źródła zmieniły się podczas kopiowania; paczka nie została opublikowana.")
        validate(stage)
        atomic_file(stage / MARKER, json.dumps({"format": 1, "files": expected}, sort_keys=True).encode())
        verify(stage)
        if build.exists():
            raise ValueError(f"Build już istnieje: {build}")
        os.replace(stage, build)
    return build


def configure(layout):
    entry, launcher = layout["entry"], layout["launcher"]
    directory = entry.parent
    backup = directory.with_name("quickshell.previous")
    if launcher.exists() and launcher.read_bytes() != (ROOT / "scripts/qs").read_bytes():
        if b"Start the default Putkin through UWSM" not in launcher.read_bytes():
            raise ValueError(f"Obce polecenie qs: {launcher}")
    if directory.exists() and not directory.is_symlink():
        if backup.exists() or backup.is_symlink():
            raise ValueError(f"Kopia wcześniejszej konfiguracji już istnieje: {backup}")
        os.replace(directory, backup)
    atomic_file(launcher, (ROOT / "scripts/qs").read_bytes(), 0o755)
    atomic_link(directory, layout["store"] / "current")


def file_state(path):
    if path.is_symlink():
        return ("link", path.readlink())
    if path.exists():
        if path.is_dir():
            return ("directory",)
        return ("file", path.read_bytes(), path.stat().st_mode & 0o777)
    return ("absent",)


def restore_file(path, state):
    if state[0] == "link":
        atomic_link(path, state[1])
    elif state[0] == "file":
        atomic_file(path, state[1], state[2])
    elif state[0] == "directory":
        if path.is_symlink():
            path.unlink()
        if not path.exists():
            os.replace(path.with_name("quickshell.previous"), path)
    else:
        path.unlink(missing_ok=True)


def publish(store, build):
    verify(build)
    old = current(store)
    if old != build:
        if old:
            atomic_link(store / "previous", old)
        atomic_link(store / "current", build)


def prune(layout):
    store = layout["store"]
    protected = {p for p in (current(store), current(store, "previous")) if p}
    ordered = releases(store)
    retained = set(protected)
    for path in ordered:
        if len(retained) < KEEP:
            retained.add(path)
    removed = []
    for path in ordered:
        if path in retained:
            continue
        # Legacy snapshots correspond exactly to the removed build; other state
        # (launcher history, preferences, migration backup) is never traversed.
        shutil.rmtree(path)
        for prefix in ("update-", "switch-"):
            snapshot = layout["state"] / (prefix + path.name)
            if snapshot.is_dir() and not snapshot.is_symlink():
                shutil.rmtree(snapshot)
        removed.append(path.name)
    return removed


def run(args, check=True):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True, timeout=20)
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or str(args))
    return result.stdout.strip()


def instances():
    output = run(["quickshell", "list", "--all", "--json"])
    return [] if output == "No running instances." else json.loads(output)


def until(predicate):
    end = time.monotonic() + 15
    while time.monotonic() < end:
        value = predicate()
        if value:
            return value
        time.sleep(.1)
    raise RuntimeError("Przekroczono czas oczekiwania na Putkin.")


class Session:
    """Only an unlocked, identified Putkin may be replaced; no broad process kills."""
    def __init__(self, layout):
        self.layout = layout
        self.old = None
        self.old_build = None
        self.mode = "off"

    def ipc(self, entry, target, method, *args):
        return run(["quickshell", "ipc", "--path", entry, "call", target, method, *args])

    def preflight(self):
        running = instances()
        if len(running) > 1:
            raise RuntimeError("Działa więcej niż jedna instancja Quickshell.")
        if running:
            self.old = running[0]
            build = Path(self.old["config_path"]).resolve().parent
            self.old_build = build
            if build not in releases(self.layout["store"]):
                raise RuntimeError("Działa inna konfiguracja Quickshell; nie zatrzymano jej.")
            self.unlocked()
            state = json.loads(self.ipc(self.old["config_path"], "caffeinate", "status"))
            if state["busy"] or state["error"]:
                raise RuntimeError("Caffeinate nie jest gotowe do przełączenia.")
            self.mode = state["mode"]

    def unlocked(self):
        if run(["hyprctl", "locked"]) != "false":
            raise RuntimeError("Sesja jest zablokowana; odblokuj ją przed aktualizacją Putkina.")
        for instance in instances():
            status = json.loads(self.ipc(instance["config_path"], "session", "status"))
            if status["busy"] or status["lock"]["locked"] or status["lock"]["secure"]:
                raise RuntimeError("Trwa blokowanie lub operacja sesji; aktualizacja zatrzymana.")

    def stop(self):
        self.unlocked()
        for instance in instances():
            if Path(instance["config_path"]).resolve().parent not in releases(self.layout["store"]):
                raise RuntimeError("Nie zatrzymano obcego shella.")
            # Stop the service's entire cgroup, including its D-Bus helpers.
            unit_pid = run(["systemctl", "--user", "show", "putkin.service", "-p", "MainPID", "--value"], check=False)
            if unit_pid == str(instance["pid"]):
                run(["systemctl", "--user", "stop", "putkin.service"])
            else:
                run(["quickshell", "kill", "--id", instance["id"]])
        until(lambda: not instances())

    def start(self, entry=None):
        if entry is None:
            entry = self.layout["entry"]
            run([self.layout["launcher"]])
        else:
            # Failure recovery may need the original absolute path, before this
            # user had a default Putkin. Restore that instance identity as well.
            launch_file = self.layout["entry"].parent.parent / "putkin/launch.json"
            options = json.loads(launch_file.read_text()) if launch_file.exists() else {}
            command = ["uwsm", "app", "-s", "s", "-t", "service", "-u", "putkin.service", "--", "env"]
            wallpaper = os.environ.get("PUTKIN_WALLPAPER", options.get("wallpaper"))
            if wallpaper is not None:
                command.append("PUTKIN_WALLPAPER=" + wallpaper)
            run(command + ["quickshell", "--no-duplicate", "--path", entry])
        instance = until(lambda: next((i for i in instances() if i["config_path"] == str(entry)), None))
        def ready():
            result = run(["quickshell", "ipc", "--id", instance["id"], "call", "session", "status"], check=False)
            if not result.startswith("{"):
                return False
            state = json.loads(result)
            return state if state["idle"]["ready"] and state["capabilities"]["lock"]["available"] else False
        until(ready)
        owner = json.loads(run(["busctl", "--user", "--json=short", "call", "org.freedesktop.DBus",
                               "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID",
                               "s", "org.freedesktop.Notifications"]))["data"][0]
        if owner != instance["pid"] or len(instances()) != 1:
            raise RuntimeError("Konflikt instancji lub właściciela powiadomień.")
        until(lambda: not json.loads(self.ipc(entry, "caffeinate", "status"))["busy"])
        if self.mode != "off":
            self.ipc(entry, "caffeinate", "setMode", self.mode)
        until(lambda: (state := json.loads(self.ipc(entry, "caffeinate", "status")))["mode"] == self.mode
              and not state["busy"] and not state["error"])
        log = run(["quickshell", "log", "--no-color", "--id", instance["id"]])
        if any(word in log for word in ("WARN", "ERROR", "TypeError", "ReferenceError", "Traceback")):
            raise RuntimeError(log)
        return instance
