"""Read-only dependency checks and imports with the actual Quickshell engine."""
import ctypes
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from _common import ROOT, tool


def version(command):
    result = subprocess.run(command, capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise RuntimeError(f"Nie można sprawdzić wersji {command[0]}: {result.stderr.strip()}")
    return result.stdout.strip()


def dependencies():
    if sys.version_info < (3, 12):
        raise RuntimeError("Instalator wymaga Python 3.12 lub nowszego (weryfikowane rozpakowywanie archiwów).")
    required = ["quickshell", "Hyprland", "uwsm", "hyprctl", "busctl", "gdbus", "systemctl",
                "python3", "dbus-run-session", "bwrap", "ffmpeg", "ffprobe", "file"]
    missing = [name for name in required if not shutil.which(name)]
    missing += ["python:" + name for name in ("dbus", "gi") if importlib.util.find_spec(name) is None]
    for name in ("qmlformat", "qmllint", "qmake6"):
        try:
            tool(name)
        except FileNotFoundError:
            missing.append(name)
    try:
        ctypes.CDLL("libqrencode.so.4")
    except OSError:
        missing.append("libqrencode.so.4")
    if missing:
        raise RuntimeError("Brak wymaganych zależności: " + ", ".join(missing)
                           + ". Arch Linux: scripts/install --install-packages (lista: config/packages/arch.txt).")
    versions = {"quickshell": version(["quickshell", "--version"]),
                "hyprland": version(["Hyprland", "--version"]),
                "qt": version([tool("qmake6"), "-query", "QT_VERSION"]),
                "uwsm": version(["uwsm", "--version"])}
    for name, minimum in (("quickshell", (0, 3, 1)), ("hyprland", (0, 56, 2)), ("qt", (6, 11, 2))):
        found = re.search(r"(\d+)\.(\d+)\.(\d+)", versions[name])
        if not found or tuple(map(int, found.groups())) < minimum:
            raise RuntimeError(f"Niezgodna wersja {name}: wymagana co najmniej {'.'.join(map(str, minimum))}; wykryto {versions[name]}.")
    versions["optional_missing"] = [name for name in ("brightnessctl", "hyprsunset", "wl-copy", "wl-paste",
                                      "cliphist", "fd", "grim", "playerctl", "kitty", "fish", "nvim", "yazi", "zen-browser", "voxtype", "starship")
                                    if not shutil.which(name)]
    return versions


def sandbox(work, source):
    command = [tool("bwrap"), "--unshare-all", "--die-with-parent", "--new-session",
               "--ro-bind", "/usr", "/usr", "--symlink", "usr/bin", "/bin",
               "--symlink", "usr/lib", "/lib", "--symlink", "usr/lib", "/lib64",
               "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp", "--dir", "/tmp/runtime",
               "--ro-bind", str(source.resolve()), "/source", "--ro-bind", str(work), "/probe", "--clearenv"]
    for key, value in {"PATH": "/usr/bin", "HOME": "/tmp/home", "LANG": "C.UTF-8",
                       "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software", "QSG_RENDER_LOOP": "basic",
                       "XDG_CONFIG_HOME": "/tmp/config", "XDG_DATA_HOME": "/tmp/data", "XDG_STATE_HOME": "/tmp/state",
                       "XDG_CACHE_HOME": "/tmp/cache", "XDG_RUNTIME_DIR": "/tmp/runtime",
                       "DBUS_SYSTEM_BUS_ADDRESS": "unix:path=/tmp/no-system-bus"}.items():
        command += ["--setenv", key, value]
    return command


def compile_runtime(source):
    # Native modules are embedded in Quickshell; qmllint alone cannot prove
    # their availability. Compile the production imports without constructing
    # a PanelWindow (which requires a real Wayland compositor), hardware or PAM.
    with tempfile.TemporaryDirectory(prefix="putkin-imports-") as directory:
        work = Path(directory)
        files = [source / "shell.qml"]
        for name in ("core", "services", "components", "modules"):
            files.extend((source / name).rglob("*.qml"))
        imports = {"import QtQuick", "import Quickshell"}
        for path in files:
            for line in path.read_text().splitlines():
                if re.fullmatch(r"import [A-Za-z][\w.]*(?: \d+\.\d+)?(?: as \w+)?\s*", line):
                    imports.add(line.strip())
        (work / "required-imports.qml").write_text("\n".join(sorted(imports)) + "\nShellRoot {}\n")
        (work / "probe.qml").write_text('''import QtQuick
import Quickshell
ShellRoot {
    Component.onCompleted: {
        const component = Qt.createComponent("required-imports.qml", Component.PreferSynchronous);
        if (component.status !== Component.Ready) {
            console.error("PUTKIN_IMPORT_ERROR: " + component.errorString());
            Qt.callLater(Qt.quit);
            return;
        }
        console.log("PUTKIN_IMPORTS_OK");
        Qt.callLater(Qt.quit);
    }
}
''')
        try:
            result = subprocess.run(sandbox(work, source) + ["--", "dbus-run-session", "--", "quickshell", "--no-color", "--path", "/probe/probe.qml"],
                                    capture_output=True, text=True, timeout=30)
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b"") + (error.stderr or b"")
            raise RuntimeError("Timeout kompilacji QML:\n" + output.decode(errors="replace")) from None
        output = result.stdout + result.stderr
        if result.returncode or "PUTKIN_IMPORTS_OK" not in output or "PUTKIN_IMPORT_ERROR" in output:
            raise RuntimeError("Quickshell nie ładuje typów runtime; instalacja zatrzymana przed przełączeniem:\n" + output)


def validate_hyprland(items, layout, source):
    config = layout["entry"].parent.parent
    hypr = config / "hypr"
    selected = [i for i in items if i["path"].is_relative_to(hypr) and i["path"].suffix == ".lua"]
    if not any(i["path"] == hypr / "hyprland.lua" for i in selected):
        return
    with tempfile.TemporaryDirectory(prefix="putkin-hypr-config-") as directory:
        work = Path(directory)
        for item in selected:
            target = work / "config" / item["path"].relative_to(config)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(item["path"].read_bytes() if item["action"] == "preserve-local" else item["data"])
        (work / "config/quickshell").symlink_to("/source")
        result = subprocess.run(sandbox(work, source) + ["--setenv", "XDG_CONFIG_HOME", "/probe/config", "--",
                                "Hyprland", "--verify-config", "--config", "/probe/config/hypr/hyprland.lua"],
                                capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise RuntimeError("Nieprawidłowa konfiguracja Hyprlanda; przed zmianą plików:\n" + result.stdout + result.stderr)


def install_packages():
    distro = Path("/etc/os-release").read_text()
    if not re.search(r"(?m)^ID=(?:arch|\"arch\")$", distro):
        raise RuntimeError("Automatyczna instalacja pakietów obsługuje Arch Linux; pozostałe systemy: docs/install.md.")
    def packages(name):
        return [line.split("#", 1)[0].strip() for line in (ROOT / "config/packages" / name).read_text().splitlines()
                if line.split("#", 1)[0].strip()]
    aur = packages("aur.txt")
    missing = [p for p in aur if subprocess.run(["pacman", "-Q", p], capture_output=True).returncode]
    helper = shutil.which("paru") or shutil.which("yay")
    if missing and not helper:
        raise RuntimeError("Pakiety AUR wymagają yay albo paru: " + ", ".join(missing)
                           + ". Zainstaluj jeden z tych programów przed --install-packages.")
    subprocess.run(["sudo", "pacman", "-Syu", "--needed", *packages("arch.txt")], check=True)
    if missing:
        subprocess.run([helper, "-S", "--needed", *missing], check=True)
