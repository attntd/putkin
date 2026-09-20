"""Read-only acceptance of the installed combined release; qs checks deduplication."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "docs/evidence"
sys.path.insert(0, str(ROOT / "scripts"))
from _install import Session, current, instances, manifest, paths, releases, run, until, verify

layout = paths()
entry = layout["entry"]
session = Session(layout)
expected = json.loads((EVIDENCE / "combined-release-source.json").read_text())
before = json.loads((EVIDENCE / "combined-release-before.json").read_text())
build = current(layout["store"])
verify(build)
assert manifest(build) == expected["files"], "Installed runtime differs from the tested source"
assert str(current(layout["store"], "previous")) == before["current"]
running = instances()
assert len(running) == 1, running
instance = running[0]
assert Path(instance["config_path"]).resolve() == build / "shell.qml"
run([layout["launcher"]])
assert instances() == running, "Repeated qs changed the instance"

def keyboard_ready():
    state = json.loads(session.ipc(entry, "actions", "status"))
    return state if state["ready"] and state["applied"] and not state["busy"] and not state["error"] else None

keyboard = until(keyboard_ready)
state = json.loads(session.ipc(entry, "session", "status"))
caffeinate = json.loads(session.ipc(entry, "caffeinate", "status"))
assert state["idle"]["ready"] and state["capabilities"]["lock"]["available"]
assert not state["error"] and not state["idle"]["error"]
assert caffeinate["mode"] == before["caffeinate"]["mode"] and not caffeinate["error"] and not caffeinate["busy"]
owner = json.loads(run(["busctl", "--user", "--json=short", "call", "org.freedesktop.DBus",
                       "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID",
                       "s", "org.freedesktop.Notifications"]))["data"][0]
assert owner == instance["pid"]
unit_text = run(["systemctl", "--user", "show", "putkin.service", "-p", "ActiveState", "-p", "SubState", "-p", "MainPID", "-p", "Slice"])
unit = dict(line.split("=", 1) for line in unit_text.splitlines())
assert unit == {"ActiveState": "active", "SubState": "running", "MainPID": str(instance["pid"]), "Slice": "session-graphical.slice"}, unit
binds = json.loads(run(["hyprctl", "-j", "binds"]))
bare_print = [b for b in binds if b.get("modmask") == 0 and str(b.get("key", "")).lower() == "print"]
assert len(bare_print) == 1 and bare_print[0]["description"] == "Putkin:screenshot", bare_print
assert not run(["hyprctl", "configerrors"]), "Hyprland configuration errors"

def namespaces(value):
    found = []
    if isinstance(value, dict):
        if "namespace" in value:
            found.append(value["namespace"])
        for child in value.values():
            found.extend(namespaces(child))
    elif isinstance(value, list):
        for child in value:
            found.extend(namespaces(child))
    return found

monitors = json.loads(run(["hyprctl", "-j", "monitors"]))
layers = json.loads(run(["hyprctl", "-j", "layers"]))
surfaces = {monitor["name"]: namespaces(layers.get(monitor["name"], {})) for monitor in monitors}
for monitor, names in surfaces.items():
    assert names.count("putkin-bar") == 1 and names.count("putkin-wallpaper") == 1, (monitor, names)
configuration = {path: hashlib.sha256(Path(path).read_bytes()).hexdigest() for path in before["configuration_sha256"]}
assert configuration == before["configuration_sha256"], "User configuration changed"
retained = releases(layout["store"])
assert len(retained) == 5
log = run(["quickshell", "log", "--no-color", "--id", instance["id"]])
(EVIDENCE / "combined-release-live.log").write_text(log + "\n")
assert not any(word in log for word in ("WARN", "ERROR", "TypeError", "ReferenceError", "Traceback")), log
report = {"timestamp_utc": datetime.now(timezone.utc).isoformat(), "result": "PASS", "build": build.name,
          "previous": before["current"], "instance": instance, "unit": unit,
          "runtime_files": len(expected["files"]), "runtime_matches_tested_source": True,
          "qs_preserved_instance": True, "notification_owner": owner, "keyboard": keyboard,
          "print": bare_print, "session": state, "caffeinate": caffeinate,
          "surfaces": surfaces, "configuration_unchanged": True,
          "retained": [path.name for path in retained], "qml_log_clean": True, "hyprland_config_clean": True}
(EVIDENCE / "combined-release-activation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(report, ensure_ascii=False, indent=2))
