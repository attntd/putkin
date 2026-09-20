#!/usr/bin/env python3
"""One-time migration of this user's existing Putkin installation to default qs."""
import difflib
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import _install as install

STAGE = Path("/tmp/putkin-default-install")
EVIDENCE = ROOT / "docs/evidence"
LAYOUT = install.paths()
CONFIG = LAYOUT["entry"].parent.parent
BACKUP = LAYOUT["state"] / "default-install"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def prepare():
    running = install.instances()
    assert len(running) == 1, running
    old = Path(running[0]["config_path"]).parent
    assert old in install.releases(LAYOUT["store"])
    previous_plan = next(json.loads(p.read_text()) for p in EVIDENCE.glob("*-activation-plan.json")
                         if json.loads(p.read_text()).get("entry") == str(old / "shell.qml"))
    assert install.manifest(old) == previous_plan["manifest"]
    STAGE.mkdir(mode=0o700)
    runtime = STAGE / "runtime"
    shutil.copytree(old, runtime, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", install.MARKER))
    shutil.copy2(ROOT / "scripts/lock-session", runtime / "scripts/lock-session")
    changed_runtime = [key for key, value in install.manifest(runtime).items() if previous_plan["manifest"].get(key) != value]
    assert changed_runtime == ["scripts/lock-session"], changed_runtime
    changes = {}
    differences = []
    def add(path, after):
        before = path.read_text()
        assert before != after, path
        target = STAGE / ("config-" + str(len(changes)))
        target.write_text(after)
        changes[str(path)] = {"before": digest(path), "after": digest(target), "staged": str(target)}
        differences.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True), str(path), str(path)))
    for relative in ("hyprland.lua", "autostart.lua", "modules/system_binds.lua"):
        live = CONFIG / "hypr" / relative
        source = Path(install.run(["chezmoi", "source-path", live]))
        for path in (live, source):
            text = path.read_text()
            if relative == "autostart.lua":
                lines = text.splitlines(True)
                matched = [i for i, line in enumerate(lines) if str(old) in line and "hl.exec_cmd" in line]
                assert len(matched) == 1
                lines[matched[0]] = "  hl.exec_cmd(" + json.dumps(shlex.quote(str(LAYOUT["launcher"]))) + ")\n"
                after = "".join(lines)
            else:
                after = text.replace(str(old), str(LAYOUT["entry"].parent))
                if relative == "modules/system_binds.lua":
                    lines = after.splitlines(True)
                    matched = [i for i, line in enumerate(lines) if "local lock_command =" in line]
                    assert len(matched) == 1
                    lines[matched[0]] = '    local lock_command = "quickshell ipc call session lock"\n'
                    after = "".join(lines)
            add(path, after)
    # The earlier shell has an independent SSH askpass helper still used by fish.
    # Preserve it in the single first-install backup and update both references.
    fish = CONFIG / "fish/conf.d/ssh-agent.fish"
    for path in (fish, Path(install.run(["chezmoi", "source-path", fish]))):
        text = path.read_text()
        add(path, text.replace("quickshell/scripts/ssh-askpass", "quickshell.previous/scripts/ssh-askpass"))
    environment = Path(f"/proc/{running[0]['pid']}/environ").read_bytes().split(b"\0")
    wallpaper = next(value.split(b"=", 1)[1].decode() for value in environment if value.startswith(b"PUTKIN_WALLPAPER="))
    preserved = {str(p): digest(p) for p in (CONFIG / "putkin/settings.json", CONFIG / "putkin/keyboard.json")}
    plan = {"old": running[0], "old_build": str(old), "old_manifest": previous_plan["manifest"],
            "changes": changes, "wallpaper": wallpaper, "preserved": preserved,
            "manifest": install.manifest(runtime), "changed_runtime": changed_runtime,
            "chezmoi_before": install.run(["chezmoi", "status"]), "builds_before": [p.name for p in install.releases(LAYOUT["store"])]}
    (STAGE / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    (EVIDENCE / "default-install-plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    (EVIDENCE / "default-install-config.diff").write_text("".join(differences))
    install.validate(runtime)
    print(json.dumps({"runtime_files": len(plan["manifest"]), "changed_runtime": changed_runtime,
                      "configurations": list(changes), "builds_before": len(plan["builds_before"]), "keep": 5}, indent=2))


def verify(plan):
    running = install.instances()
    assert len(running) == 1 and running[0]["config_path"] == str(LAYOUT["entry"]), running
    instance = running[0]
    prefix = ["quickshell", "ipc", "call"]
    session = json.loads(install.run(prefix + ["session", "status"]))
    assert session["idle"]["ready"] and session["capabilities"]["lock"]["available"], session
    assert not session["lock"]["locked"]
    unit = install.run(["systemctl", "--user", "show", "putkin.service", "-p", "ActiveState", "-p", "SubState", "-p", "MainPID", "-p", "Slice", "-p", "ControlGroup"])
    assert f"MainPID={instance['pid']}" in unit and "ActiveState=active" in unit and "Slice=session-graphical.slice" in unit, unit
    assert "putkin.service" in Path(f"/proc/{instance['pid']}/cgroup").read_text()
    install.run([LAYOUT["launcher"]])
    assert install.instances() == running, "Second qs created another instance"
    owner = json.loads(install.run(["busctl", "--user", "--json=short", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
                                  "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", "org.freedesktop.Notifications"]))["data"][0]
    assert owner == instance["pid"]
    monitors = json.loads(install.run(["hyprctl", "-j", "monitors"]))
    layers = json.loads(install.run(["hyprctl", "-j", "layers"]))
    for monitor in monitors:
        rows = [row for level in layers[monitor["name"]]["levels"].values() for row in level]
        for namespace in ("putkin-bar", "putkin-wallpaper"):
            assert len([row for row in rows if row["namespace"] == namespace and row["pid"] == instance["pid"]]) == 1
    assert install.run(prefix + ["ui", "openSettings"]) == "ok"
    try:
        install.until(lambda: any(c["pid"] == instance["pid"] and c["title"] == "Ustawienia"
                                 for c in json.loads(install.run(["hyprctl", "-j", "clients"]))))
    finally:
        install.run(prefix + ["ui", "closePanels"])
    actions = install.until(lambda: (state if state["ready"] and not state["busy"] else None)
                            if (state := json.loads(install.run(prefix + ["actions", "status"]))) else None)
    assert actions["applied"] and not actions["error"], actions
    assert not install.run(["hyprctl", "configerrors"])
    for path, expected in plan["preserved"].items():
        assert digest(Path(path)) == expected, path
    log = install.run(["quickshell", "log", "--no-color", "--id", instance["id"]])
    (EVIDENCE / "default-install-live.log").write_text(log + "\n")
    assert not any(word in log for word in ("WARN", "ERROR", "Traceback", "TypeError", "ReferenceError")), log
    result = {"instance": instance, "unit": unit, "notifications_owner": owner, "session": session,
              "caffeinate": json.loads(install.run(prefix + ["caffeinate", "status"])), "actions": actions,
              "bar_and_wallpaper": True, "settings_window": True, "second_qs_same_pid": True,
              "preserved": plan["preserved"], "current": str(install.current(LAYOUT["store"])),
              "retained": [p.name for p in install.releases(LAYOUT["store"])]}
    return result


def apply(retry=False):
    plan = json.loads((STAGE / "plan.json").read_text())
    running = install.instances()
    assert len(running) == 1 and running[0]["config_path"] == plan["old"]["config_path"]
    if not retry:
        assert running == [plan["old"]]
    assert install.manifest(Path(plan["old_build"])) == plan["old_manifest"]
    assert install.manifest(STAGE / "runtime") == plan["manifest"]
    for path, change in plan["changes"].items():
        assert digest(Path(path)) == change["before"], path
        assert digest(Path(change["staged"])) == change["after"]
    session = install.Session(LAYOUT)
    session.preflight()
    BACKUP.mkdir(mode=0o700, exist_ok=retry)
    shutil.copy2(STAGE / "plan.json", BACKUP / "plan.json")
    for index, path in enumerate(plan["changes"]):
        shutil.copy2(path, BACKUP / str(index))
    launch = CONFIG / "putkin/launch.json"
    assert not launch.exists()
    assert not LAYOUT["launcher"].exists()
    assert not (LAYOUT["store"] / "current").exists() or (retry and install.current(LAYOUT["store"]) == Path(plan["old_build"]))
    old = Path(plan["old_build"])
    install.atomic_file(old / install.MARKER, json.dumps({"format": 1, "files": plan["old_manifest"]}).encode())
    install.atomic_link(LAYOUT["store"] / "current", old)
    install.atomic_file(launch, json.dumps({"wallpaper": plan["wallpaper"]}, indent=2).encode() + b"\n")
    try:
        subprocess.run([ROOT / "scripts/install", "--source", STAGE / "runtime", "--activate", "--no-prune"], check=True)
        for path, change in plan["changes"].items():
            assert digest(Path(path)) == change["before"], path
            install.atomic_file(Path(path), Path(change["staged"]).read_bytes(), Path(path).stat().st_mode & 0o777)
        install.run(["hyprctl", "reload"])
        result = verify(plan)
    except BaseException:
        # No pruning happens before this point: original code and default config
        # are still present. Restore only files whose post-migration bytes match.
        session.stop()
        for index, (path, change) in enumerate(plan["changes"].items()):
            if digest(Path(path)) == change["after"]:
                install.atomic_file(Path(path), (BACKUP / str(index)).read_bytes(), Path(path).stat().st_mode & 0o777)
        directory = LAYOUT["entry"].parent
        if directory.is_symlink():
            directory.unlink()
            os.replace(directory.with_name("quickshell.previous"), directory)
        LAYOUT["launcher"].unlink(missing_ok=True)
        launch.unlink(missing_ok=True)
        install.atomic_link(LAYOUT["store"] / "current", old)
        install.run(["hyprctl", "reload"])
        install.run(["uwsm", "app", "--", "env", "PUTKIN_WALLPAPER=" + plan["wallpaper"], "quickshell", "--no-duplicate", "--daemonize", "--path", old / "shell.qml"])
        install.until(lambda: install.instances())
        if session.mode != "off":
            session.ipc(old / "shell.qml", "caffeinate", "setMode", session.mode)
        raise
    install.run(["chezmoi", "add", "--recursive=false", LAYOUT["launcher"], LAYOUT["entry"].parent, launch])
    result["removed"] = install.prune(LAYOUT)
    result["retained"] = [p.name for p in install.releases(LAYOUT["store"])]
    assert len(result["retained"]) == 5
    result["chezmoi_after"] = install.run(["chezmoi", "status"])
    assert result["chezmoi_after"] == plan["chezmoi_before"], result["chezmoi_after"]
    (EVIDENCE / "default-install-activation.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    if sys.argv[1:] == ["--prepare"]:
        prepare()
    elif sys.argv[1:] == ["--apply"]:
        apply()
    elif sys.argv[1:] == ["--retry"]:
        apply(retry=True)
    else:
        raise SystemExit("Use --prepare or --apply")
