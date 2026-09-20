"""Activate the reviewed screenshot runtime and migrate only bare Print."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from _install import Session, atomic_file, current, manifest, paths, run, source_files, until

EVIDENCE = ROOT / "docs/evidence"
layout = paths()
session = Session(layout)
session.preflight()
previous = current(layout["store"])
before = manifest(previous)
after = source_files(ROOT)
changed = sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))
expected = sorted("""core/ActionController.qml core/Actions.js core/Metrics.qml core/Theme.qml
modules/screenshot/ScreenshotHost.qml modules/screenshot/ScreenshotPreview.qml
modules/screenshot/SelectionView.qml modules/screenshot/qmldir
services/ScreenshotBackend.qml services/ScreenshotService.qml services/keyboard.py
services/qmldir services/screenshot_backend.py shell.qml""".split())
assert changed == expected, changed
assert shutil.which("grim") and shutil.which("wl-copy")

old_block = '''    screenshot = {
        global = "quickshell-de:screenshot-open",
        bind = "PRINT",
        description = "[Screenshot] Open QuickShell capture",
    },
'''
replacement = '    -- Print obsługuje działanie screenshot Putkina (Ustawienia → Klawiatura).\n'
targets = [Path.home() / ".config/hypr/keybinds.lua",
           Path.home() / ".local/share/chezmoi/dot_config/hypr/keybinds.lua"]
snapshots = {}
proposed = {}
diff = []
for path in targets:
    data = path.read_bytes()
    assert hashlib.sha256(data).hexdigest() == "2d4c24e1bdba00fe987ada4ff5a2cb6fc796047d0d0923bc8e3681e2d2bd376c", path
    text = data.decode()
    assert text.count(old_block) == 1, path
    snapshots[path] = (data, path.stat().st_mode & 0o777)
    proposed[path] = text.replace(old_block, replacement).encode()
    diff.extend(difflib.unified_diff(text.splitlines(True), proposed[path].decode().splitlines(True),
                                     fromfile=str(path), tofile=str(path)))
(EVIDENCE / "screenshot-activation-config.diff").write_text("".join(diff))
(EVIDENCE / "screenshot-activation-before.json").write_text(json.dumps({
    "previous": str(previous), "instance": session.old, "caffeinate": session.mode,
    "changed_runtime_files": changed,
    "print_before": [b for b in json.loads(run(["hyprctl", "-j", "binds"]))
                     if str(b.get("key", "")).lower() == "print"],
}, indent=2, ensure_ascii=False) + "\n")

try:
    for path in targets:
        assert path.read_bytes() == snapshots[path][0], path
        atomic_file(path, proposed[path], snapshots[path][1])
        run(["luac", "-p", path])
    run(["hyprctl", "reload"])
    assert not run(["hyprctl", "configerrors"]), "Hyprland configuration errors"
    until(lambda: not any(b.get("modmask") == 0 and str(b.get("key", "")).lower() == "print"
                          for b in json.loads(run(["hyprctl", "-j", "binds"]))))
    print("Bare Print released from the retired shell; other bindings retained.", flush=True)
    subprocess.run([str(ROOT / "scripts/install"), "--activate"], check=True)
except BaseException:
    # The installer owns runtime rollback. Restore only our exact config edit.
    for path, (data, mode) in snapshots.items():
        if path.read_bytes() == proposed[path]:
            atomic_file(path, data, mode)
    run(["hyprctl", "reload"], check=False)
    raise

entry = layout["entry"]
def keyboard_ready():
    value = json.loads(session.ipc(entry, "actions", "status"))
    return value if value["ready"] and value["applied"] and not value["busy"] and not value["error"] else None
keyboard = until(keyboard_ready)
binds = json.loads(run(["hyprctl", "-j", "binds"]))
bare_print = [b for b in binds if b.get("modmask") == 0 and str(b.get("key", "")).lower() == "print"]
assert len(bare_print) == 1 and bare_print[0]["description"] == "Putkin:screenshot", bare_print
assert not run(["hyprctl", "configerrors"])
from _install import instances, releases, verify
active = current(layout["store"])
verify(active)
assert manifest(active) == after
live = instances()
assert len(live) == 1
log = run(["quickshell", "log", "--no-color", "--id", live[0]["id"]])
(EVIDENCE / "screenshot-activation-live.log").write_text(log + "\n")
assert not any(word in log for word in ("WARN", "ERROR", "TypeError", "ReferenceError", "Traceback")), log
report = {"result": "PASS", "build": active.name, "previous": str(previous), "instance": live[0],
          "unit": run(["systemctl", "--user", "show", "putkin.service", "-p", "ActiveState", "-p", "SubState", "-p", "MainPID", "-p", "Slice"]),
          "keyboard": keyboard, "print": bare_print,
          "session": json.loads(session.ipc(entry, "session", "status")),
          "caffeinate": json.loads(session.ipc(entry, "caffeinate", "status")),
          "retained": [p.name for p in releases(layout["store"])], "runtime_files": len(after)}
(EVIDENCE / "screenshot-activation.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(report, indent=2, ensure_ascii=False), flush=True)
