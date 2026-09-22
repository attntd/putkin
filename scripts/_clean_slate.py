"""Bounded desktop reset: local archives, protected data and legacy autostarts."""
import os
from pathlib import Path
import shlex
import shutil

from _install import ROOT, atomic_link, run
from _dotfiles import FORBIDDEN, safe_target

# These directories contain configuration, not whole browser/account profiles.
# Keep this list explicit: a new catalog entry must never authorize wiping HOME.
CONFIG_TREES = {
    "hypr", "kitty", "fish", "nvim", "yazi", "Kvantum", "gtk-3.0", "gtk-4.0",
    "qt5ct", "qt6ct", "glow", "btop", "uwsm", "voxtype", "putkin",
    "quickshell", "quickshell.previous", "quickshell-de", "putpuccin",
    "waybar", "ags", "eww", "hyprpanel", "dms", "noctalia",
    "swaync", "dunst", "mako", "hypridle", "hyprlock", "hyprpaper", "swww",
}
LEGACY = {"quickshell", "quickshell-de", "putpuccin", "waybar", "ags", "eww",
          "hyprpanel", "dms", "noctalia-shell", "swaync", "dunst", "mako",
          "hypridle", "hyprlock", "hyprpaper", "swww", "swww-daemon", "swaybg", "swayidle"}
PROTECTED = FORBIDDEN | {"bookmarks", "token", "tokens", "credentials", "secrets", "keyring",
                         "private-keys-v1.d", "authorized_keys", "known_hosts", "signal"}
PROTECTED_SUFFIXES = {".pem", ".key", ".sqlite", ".sqlite3", ".db", ".p12", ".pfx", ".env"}


def protected(path):
    return (any(p in PROTECTED or p.startswith((".env.", "id_rsa", "id_ed25519")) for p in path.parts)
            or path.suffix in PROTECTED_SUFFIXES)


def check_path(layout, path):
    config = layout["entry"].parent.parent
    if not path.is_relative_to(config) or path == config or ".." in path.parts:
        raise ValueError("Obcy katalog czyszczenia: " + str(path))
    name = path.relative_to(config)
    allowed = name.parts[0] in CONFIG_TREES
    allowed |= name.parts[:2] == ("systemd", "user") and len(name.parts) > 2
    allowed |= name.parts[0] == "autostart" and len(name.parts) == 2 and name.suffix == ".desktop"
    allowed |= name.parts[0] == "zen" and "chrome" in name.parts[2:]
    if not allowed or protected(name):
        raise ValueError("Chronione dane poza zakresem czyszczenia: " + str(path))
    for retained in (layout["state"], layout["store"], ROOT):
        if retained.is_relative_to(path) or path.is_relative_to(retained):
            raise ValueError("Katalog czyszczenia nakłada się na runtime, backup lub źródła instalatora: " + str(path))
    link = safe_target(path, config, allow_links=True, allow_directory=True)
    if link is not None and link != path:
        raise ValueError("Dowiązanie nadrzędne katalogu czyszczenia: " + str(link))


def branches(path, preserved):
    """Partition a tree around private files; never descend through a link."""
    if protected(Path(path.name)):
        if path.exists() or path.is_symlink():
            preserved.append(path)
        return []
    if path.is_dir() and not path.is_symlink():
        children = sorted(path.iterdir())
        old_count = len(preserved)
        parts = [part for child in children for part in branches(child, preserved)]
        if len(preserved) != old_count:
            return parts
    return [path]


def legacy_command(value):
    try:
        args = shlex.split(value)
    except ValueError:
        return False
    if not args:
        return False
    command = Path(args[0].lstrip("-+!:@")).name
    if command in LEGACY or command == "qs":
        return True
    if command in ("sh", "bash", "dash", "zsh", "fish") and "-c" in args:
        index = args.index("-c") + 1
        if index < len(args):
            return legacy_command(args[index])
    if command == "env":
        rest = args[1:]
        while rest and ("=" in rest[0] or rest[0] == "--"):
            rest.pop(0)
        return legacy_command(shlex.join(rest))
    if command == "uwsm" and "--" in args:
        return legacy_command(shlex.join(args[args.index("--") + 1:]))
    if command == "systemctl" and "start" in args:
        return any(Path(name).stem in LEGACY for name in args[args.index("start") + 1:])
    return False


def legacy_entry(path, unit=False):
    def known(name):
        return name.stem.split("@", 1)[0].split(".")[-1] in LEGACY
    if known(path):
        return True
    if path.is_symlink():
        return known(path.readlink())
    if not path.is_file():
        return False  # Never inspect an arbitrary symlink destination.
    text = path.read_text(errors="replace")
    # Match commands, not comments/descriptions mentioning another desktop.
    keys = ("ExecStart", "ExecStartPre", "ExecStartPost") if unit else ("Exec", "TryExec")
    return any(legacy_command(line.split("=", 1)[1]) for line in text.splitlines()
               if "=" in line and line.split("=", 1)[0].strip() in keys)


def desktop_roots(destination=False):
    if destination:
        return [], []
    xdg = [Path(p) for p in os.environ.get("XDG_CONFIG_DIRS", "/etc/xdg").split(":") if p.startswith("/")]
    return [p / "autostart" for p in xdg], [Path("/etc/systemd/user"), Path("/usr/lib/systemd/user")]


def plan(layout, items, destination=False):
    config = layout["entry"].parent.parent
    preserved, resets = [], []
    for name in sorted(CONFIG_TREES):
        root = config / name
        check_path(layout, root)
        resets.extend(branches(root, preserved))
    # Only presentation settings in the existing default profile. Cookies,
    # passwords, prefs.js, extensions and profiles.ini retain their identity.
    for item in items:
        if item.get("target", "").startswith("zen:chrome/"):
            depth = len(Path(item["target"].removeprefix("zen:")).parts)
            root = item["path"].parents[depth - 2]
            if root not in resets:
                check_path(layout, root)
                resets.extend(branches(root, preserved))
    autostarts, unit_roots = desktop_roots(destination)
    autostarts.insert(0, config / "autostart")
    units = config / "systemd/user"
    unit_roots.insert(0, units)
    additions, masked = [], set()
    # Known units are masked even when supplied by a package later. Custom
    # unit names are discovered by their ExecStart in readable unit files.
    names = {name + ".service" for name in LEGACY}
    for directory in unit_roots:
        safe_target(directory, directory.parent, allow_directory=True)
        if directory.is_dir():
            names.update(p.name for p in directory.glob("*.service")
                         if p.name != "putkin.service" and legacy_entry(p, unit=True))
    for name in sorted(names):
        path = units / name
        check_path(layout, path)
        resets.append(path)
        override = path.with_name(name + ".d")
        if override.exists() or override.is_symlink():
            check_path(layout, override)
            resets.extend(branches(override, preserved))
        additions.append({"path": path, "action": "install", "output_link": "/dev/null", "mode": 0o600})
        masked.add(name)
    if units.is_dir():
        for directory in sorted(units.iterdir()):
            if directory.name.endswith((".wants", ".requires")):
                safe_target(directory, config, allow_directory=True)
                if directory.is_dir():
                    for path in sorted(directory.iterdir()):
                        if path.name in masked:
                            resets.append(path)
    seen_desktops = set()
    for directory in autostarts:
        safe_target(directory, directory.parent, allow_directory=True)
        if not directory.is_dir():
            continue
        for entry in sorted(directory.glob("*.desktop")):
            if entry.name in seen_desktops or not legacy_entry(entry):
                continue
            seen_desktops.add(entry.name)
            target = config / "autostart" / entry.name
            resets.append(target)
            # XDG's Hidden override also blocks a matching system-wide entry.
            additions.append({"path": target, "action": "install", "mode": 0o600,
                              "data": b"[Desktop Entry]\nType=Application\nName=Disabled by Putkin\nHidden=true\n"})
    # The old qs launcher is configuration too; clean-slate may replace it.
    launcher = layout["launcher"]
    additions.append({"path": launcher, "data": (ROOT / "scripts/qs").read_bytes(),
                      "action": "install", "mode": 0o755,
                      "link": safe_target(launcher, launcher.parent, allow_links=True)})
    roots = []
    for path in sorted(set(resets), key=lambda p: (len(p.parts), str(p))):
        if not any(path.is_relative_to(parent) for parent in roots):
            check_path(layout, path)
            roots.append(path)
    for item in items:
        if any(item["path"] == p or item["path"].is_relative_to(p) for p in preserved):
            raise ValueError("Konfiguracja koliduje z chronionymi danymi: " + str(item["path"]))
    return roots, additions, {"reset": [str(p) for p in roots], "preserved": [str(p) for p in sorted(set(preserved))],
                              "maskedUnits": sorted(masked), "disabledAutostarts": sorted(seen_desktops)}


def snapshot_resets(layout, roots, backup):
    safe_target(backup, layout["state"], allow_directory=True)
    result = []
    for index, path in enumerate(roots):
        check_path(layout, path)
        stored = backup / ("tree-" + str(index))
        record = {"path": str(path), "backup": None, "kind": "absent"}
        if path.is_symlink():
            record.update(kind="link", link=str(path.readlink()))
        elif path.exists():
            private = []
            branches(path, private)
            if private:
                raise ValueError("Zakres czyszczenia zmienił się: " + str(path))
            if path.is_dir():
                shutil.copytree(path, stored, symlinks=True)
                record["kind"] = "directory"
            else:
                shutil.copy2(path, stored)
                record["kind"] = "file"
            record["backup"] = str(stored)
        result.append(record)
    return result


def validate_resets(layout, records):
    for item in records:
        check_path(layout, Path(item["path"]))
        if item["kind"] not in ("absent", "file", "directory", "link"):
            raise ValueError("Nieprawidłowa kopia czystej instalacji.")
        if item["backup"] is not None:
            stored = Path(item["backup"])
            safe_target(stored, layout["state"] / "config-backups", allow_directory=True)
            if stored.is_dir() != (item["kind"] == "directory") or not stored.exists():
                raise ValueError("Brak kopii czystej instalacji: " + str(stored))


def remove_reset(layout, path):
    check_path(layout, path)
    private = []
    branches(path, private)
    if private:
        raise ValueError("Nowe chronione dane w katalogu czyszczenia: " + str(path))
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink(missing_ok=True)


def restore_resets(layout, records):
    # Validate the whole archive before the first removal; retain it afterwards.
    validate_resets(layout, records)
    for item in reversed(records):
        path = Path(item["path"])
        remove_reset(layout, path)
        if item["kind"] == "link":
            atomic_link(path, item["link"])
        elif item["backup"]:
            path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            if item["kind"] == "directory":
                shutil.copytree(item["backup"], path, symlinks=True)
            else:
                shutil.copy2(item["backup"], path)


def require_logged_out():
    processes = run(["ps", "-u", str(os.getuid()), "-o", "comm="]).splitlines()
    desktops = {"Hyprland", "quickshell", "sway", "weston", "wayfire", "gnome-shell", "kwin_wayland", "kwin_x11", "Xorg"}
    if desktops.intersection(p.strip() for p in processes):
        raise RuntimeError("--clean-slate wymaga wylogowania z sesji graficznej. Uruchom instalator z TTY po wylogowaniu.")


class LegacyServices:
    """Only explicit legacy units; no system services and no broad process kills."""
    def __init__(self, names):
        self.names, self.active = names, []

    def stop(self):
        for name in self.names:
            state = run(["systemctl", "--user", "show", name, "-p", "ActiveState", "--value"])
            if state in ("active", "activating", "reloading"):
                self.active.append(name)
                run(["systemctl", "--user", "stop", name])

    def reload(self):
        run(["systemctl", "--user", "daemon-reload"])

    def rollback(self):
        self.reload()
        for name in self.active:
            run(["systemctl", "--user", "start", name])
