"""Explicit config catalog, portable Zen settings and reversible file updates."""
import configparser
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import tempfile

from _install import atomic_file, atomic_link

FORBIDDEN = {".ssh", ".gnupg", ".git", ".env", "Signal", "signal-cli", "storage",
             "cookies.sqlite", "key4.db", "cert9.db", "logins.json", "logins.db", "prefs.js",
             "places.sqlite", "sessionstore.jsonlz4", "fish_variables", "history.sqlite3"}
ZEN_FILES = {"user.js", "zen-keyboard-shortcuts.json"}
HOME_SETTINGS = {".tmux.conf", ".gitconfig", ".ssh/config", ".gnupg/gpg-agent.conf"}


def relative(name):
    path = PurePosixPath(name)
    if not name or path.is_absolute() or ".." in path.parts or str(path) != name:
        raise ValueError("Nieprawidłowa ścieżka konfiguracji: " + name)
    if any(part in FORBIDDEN or part.startswith(".env.") or part.startswith("id_rsa")
           or part.startswith("id_ed25519") for part in path.parts) or path.suffix in (".pem", ".key", ".sqlite", ".db"):
        raise ValueError("Prywatne dane nie należą do konfiguracji: " + name)
    return path


def check_content(name, data):
    """Reject obvious credentials without printing their contents."""
    if len(data) > 32 * 1024 * 1024:
        raise ValueError("Zbyt duży plik konfiguracji: " + name)
    if data.startswith((b"\x89PNG\r\n", b"\xff\xd8\xff")):
        return
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        raise ValueError("Nieobsługiwany plik binarny konfiguracji: " + name) from None
    secret = re.search(r"-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{25,})", text)
    for line in text.splitlines():
        if Path(name).suffix in (".css", ".svg", ".xml") or Path(name).name.startswith("LICENSE") or line.lstrip().startswith(("#", "--", "//")):
            continue
        match = re.search(r'''(?i)\b[\w.-]*(?:api[_-]?key|access[_-]?token|password|secret)\b["']?\s*(?:[:=]\s*|\s+)(.+)''', line)
        if match:
            value = match[1].strip().strip(",;\"'")
            if value and value not in ("false", "true", "None", "null") and not any(
                    marker in value for marker in ("$", "getenv", "environ", "vim.env", "function", "{")):
                secret = True
    if secret:
        raise ValueError("Możliwy sekret w konfiguracji; plik pominięty bez ujawniania wartości: " + name)


def safe_target(path, base, allow_links=False, allow_directory=False):
    if not path.is_relative_to(base):
        raise ValueError("Konfiguracja wychodzi poza katalog docelowy.")
    for parent in (*reversed(path.parents), path):
        if parent.is_symlink():
            if allow_links and parent != base and parent.is_relative_to(base):
                return parent  # Replace this link itself, never read its destination.
            raise ValueError("Dowiązanie w celu konfiguracji: " + str(path))
    if path.exists() and not (allow_directory and path.is_dir()) and (not path.is_file() or path.stat().st_nlink != 1):
        raise ValueError("Nieprawidłowy cel konfiguracji: " + str(path))


def zen_profile(config):
    base = config / "zen"
    ini = base / "profiles.ini"
    safe_target(ini, config)
    profiles = configparser.ConfigParser(interpolation=None)
    profiles.optionxform = str
    if ini.exists():
        profiles.read(ini)
        candidates = []
        for section in profiles.sections():
            if section.startswith("Install") and profiles[section].get("Default"):
                candidates.append(profiles[section]["Default"])
        for section in profiles.sections():
            if section.startswith("Profile") and profiles[section].get("Default") == "1":
                candidates.append(profiles[section].get("Path", ""))
        if not candidates:
            candidates = [profiles[s].get("Path", "") for s in profiles.sections() if s.startswith("Profile")]
        candidates = list(dict.fromkeys(candidates))
        if len(candidates) != 1:
            raise ValueError("Zen: niejednoznaczny profil domyślny w profiles.ini; wybierz profil domyślny w Zen.")
        name = candidates[0]
        relative(name)
        profile = base / name
        # No writes through a profile symlink or an absolute foreign profile.
        safe_target(profile / "user.js", config)
        return profile, None
    profile = base / "putkin.default"
    profiles.read_dict({"General": {"StartWithLastProfile": "1", "Version": "2"},
                        "Profile0": {"Name": "Putkin", "IsRelative": "1", "Path": profile.name, "Default": "1"}})
    stream = io.StringIO()
    profiles.write(stream, space_around_delimiters=False)
    return profile, stream.getvalue().encode()


def entries(source, layout, clean_slate=False):
    catalog = source / "catalog.json"
    if not catalog.exists():
        return []
    spec = json.loads(catalog.read_text())
    if spec.get("format") != 1 or not isinstance(spec.get("files"), list):
        raise ValueError("Nieprawidłowy config/catalog.json.")
    config = layout["entry"].parent.parent
    bases = {"config": config, "data": layout["store"].parent,
             "bin": layout["launcher"].parent, "home": layout.get("home", Path.home())}
    result, seen = [], set()
    profile = None
    for item in spec["files"]:
        origin = source / relative(item["source"])
        if origin.is_symlink() or not origin.resolve().is_relative_to(source.resolve()) or not origin.is_file():
            raise ValueError("Nieprawidłowe źródło konfiguracji: " + str(origin))
        area, name = item["target"].split(":", 1)
        name = PurePosixPath(name) if area == "home" and name in HOME_SETTINGS else relative(name)
        if area == "zen":
            if str(name) not in ZEN_FILES and not (name.parts[0] == "chrome" and name.suffix in (".css", ".svg")):
                raise ValueError("Zen eksportuje wyłącznie wygląd i skróty.")
            if profile is None:
                profile, ini = zen_profile(config)
                if ini:
                    result.append({"path": config / "zen/profiles.ini", "data": ini, "policy": "seed", "mode": 0o600})
            target, base = profile / name, config
        else:
            if area not in bases or area == "home" and str(name) not in HOME_SETTINGS:
                raise ValueError("Nieobsługiwany cel konfiguracji: " + item["target"])
            if area == "data" and name.parts[0] not in ("applications", "themes", "icons"):
                raise ValueError("Dane aplikacji nie należą do dotfiles: " + item["target"])
            if area == "config" and len(name.parts) > 1 and name.parts[:2] == ("putkin", "signal"):
                raise ValueError("Dane konta Signal nie należą do dotfiles.")
            target, base = bases[area] / name, bases[area]
        link = safe_target(target, base, allow_links=True, allow_directory=clean_slate)
        if area == "home" and link is not None and link != target:
            raise ValueError("Nie zastępuję katalogu SSH/GPG będącego dowiązaniem: " + str(link))
        if target in seen:
            raise ValueError("Powtórzony cel konfiguracji: " + str(target))
        seen.add(target)
        data = origin.read_bytes()
        check_content(item["source"], data)
        if item["target"] == "home:.gnupg/gpg-agent.conf":
            if "\n" in str(config) or "\r" in str(config):
                raise ValueError("Ścieżka konfiguracji GPG nie może zawierać nowej linii.")
            data = data.replace(b"@XDG_CONFIG_HOME@", str(config).encode())
        policy = item.get("policy", "managed")
        if policy not in ("managed", "seed"):
            raise ValueError("Nieznana polityka aktualizacji konfiguracji.")
        result.append({"source": item["source"], "target": item["target"], "path": target, "data": data, "policy": policy,
                       "mode": 0o755 if area == "bin" else 0o600, "link": link})
    return result


def checksum(data):
    return hashlib.sha256(data).hexdigest()


def plan(source, layout, replace=False, clean_slate=False):
    if clean_slate:
        # No local edits, seed files or legacy monitor settings survive a reset.
        return [{**item, "action": "install"} for item in entries(source, layout, clean_slate=True)]
    record = layout["state"] / "config-files.json"
    previous = json.loads(record.read_text()) if record.exists() else {}
    result = []
    for item in entries(source, layout):
        path = item["path"]
        legacy_monitors = path.with_name("monitors.lua")
        if item.get("source") == "hypr/local.lua" and not path.exists() and legacy_monitors.is_file():
            safe_target(legacy_monitors, layout["entry"].parent.parent)
            data = legacy_monitors.read_bytes()
            check_content("hypr/monitors.lua", data)
            item = {**item, "data": b"-- Monitory zachowane podczas lokalnej migracji.\n" + data}
        old = path.read_bytes() if not item.get("link") and path.exists() else None
        action = "replace-link" if item.get("link") else "install"
        if item.get("link") and str(path) in previous and not replace:
            action = "preserve-local"
        if old == item["data"]:
            action = "unchanged"
        elif old is not None:
            if item["policy"] == "seed" or (str(path) in previous and checksum(old) != previous[str(path)] and not replace):
                action = "preserve-local"
            else:
                action = "update"
        result.append({**item, "action": action})
    return result


def summary(items):
    return [{"path": str(item["path"]), "action": item["action"]} for item in items]


class Transaction:
    """Journal before the first write; backups survive success and process death."""
    def __init__(self, layout, items, resets=()):
        self.layout, self.items = layout, items
        self.resets = list(resets)
        self.pending = layout["state"] / "config-pending.json"
        self.backup = None

    @staticmethod
    def recover(layout):
        pending = layout["state"] / "config-pending.json"
        if not pending.exists():
            return
        record = json.loads(pending.read_text())
        resets = record.get("resets", [])
        if resets:
            from _clean_slate import restore_resets, validate_resets
            validate_resets(layout, resets)
        links = [Path(i["path"]) for i in record["files"] if i.get("link") is not None]
        for item in reversed(record["files"]):
            path = Path(item["path"])
            if item.get("link") is not None:
                safe_target(path, backup_base(layout, path), allow_links=True, allow_directory=True)
                if path.is_dir() and not path.is_symlink():
                    # Remove only empty directories created beneath the old link.
                    for directory in sorted((p for p in path.rglob("*") if p.is_dir() and not p.is_symlink()),
                                            key=lambda p: len(p.parts), reverse=True):
                        directory.rmdir()
                    path.rmdir()
                atomic_link(path, item["link"])
                continue
            if any(path.is_relative_to(link) and link.is_symlink() for link in links):
                continue  # The interrupted apply never replaced this link.
            # Refuse new links instead of following them during recovery.
            safe_target(path, backup_base(layout, path), allow_links=item.get("installedLink") is not None)
            if item.get("installedLink") is not None and path.is_symlink():
                if str(path.readlink()) != item["installedLink"]:
                    raise ValueError("Zmienione dowiązanie przy odtwarzaniu: " + str(path))
                path.unlink()
            if item["backup"] is None:
                path.unlink(missing_ok=True)
            else:
                backup = Path(item["backup"])
                safe_target(backup, layout["state"] / "config-backups")
                atomic_file(path, backup.read_bytes(), item["mode"])
        if resets:
            restore_resets(layout, resets)
        pending.unlink()

    def apply(self):
        changed = [i for i in self.items if i["action"] in ("install", "update", "replace-link")]
        if not changed and not self.resets:
            return
        state = self.layout["state"]
        state.mkdir(parents=True, exist_ok=True, mode=0o700)
        parent = state / "config-backups"
        parent.mkdir(exist_ok=True, mode=0o700)
        self.backup = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-"), dir=parent))
        covered = lambda path: any(path.is_relative_to(root) for root in self.resets)
        links = sorted({i["link"] for i in changed if i.get("link") and not covered(i["link"])})
        files = [{"path": str(link), "link": str(link.readlink()), "backup": None, "mode": 0o777} for link in links]
        # Bookkeeping is part of rollback if interrupted during commit too.
        for index, item in enumerate(changed + [{"path": state / "config-files.json", "mode": 0o600}]):
            path = item["path"]
            if path in links or covered(path):
                continue
            backup = self.backup / str(index) if not any(path.is_relative_to(link) for link in links) and path.exists() else None
            if backup:
                atomic_file(backup, path.read_bytes())
            files.append({"path": str(path),
                          "backup": str(backup) if backup else None,
                          "mode": path.stat().st_mode & 0o777 if backup else item["mode"],
                          "installedLink": item.get("output_link")})
        resets = []
        if self.resets:
            from _clean_slate import snapshot_resets, remove_reset
            resets = snapshot_resets(self.layout, self.resets, self.backup)
        raw = json.dumps({"files": files, "resets": resets}, indent=2).encode()
        atomic_file(self.backup / "manifest.json", raw)
        atomic_file(self.pending, raw)
        for item in resets:
            remove_reset(self.layout, Path(item["path"]))
        for link in links:
            link.unlink()
        for item in changed:
            if item.get("output_link") is not None:
                atomic_link(item["path"], item["output_link"])
            else:
                atomic_file(item["path"], item["data"], item["mode"])

    def commit(self):
        path = self.layout["state"] / "config-files.json"
        previous = json.loads(path.read_text()) if path.exists() and not self.resets else {}
        previous = {p: value for p, value in previous.items() if not any(Path(p).is_relative_to(root) for root in self.resets)}
        previous.update({str(i["path"]): checksum(i["data"]) for i in self.items
                         if i["action"] != "preserve-local" and i.get("output_link") is None})
        if self.items:
            atomic_file(path, json.dumps(previous, sort_keys=True).encode())
        self.pending.unlink(missing_ok=True)

    def rollback(self):
        self.recover(self.layout)


def backup_base(layout, path):
    if path == layout["state"] / "config-files.json":
        return layout["state"]
    for base in (layout["entry"].parent.parent, layout["store"].parent, layout["launcher"].parent):
        if path.is_relative_to(base):
            relative(str(path.relative_to(base)))
            return base
    if path.is_relative_to(layout["home"]) and str(path.relative_to(layout["home"])) in HOME_SETTINGS:
        return layout["home"]
    raise ValueError("Obcy cel kopii konfiguracji: " + str(path))


def export(source, layout, output):
    """Read only catalogued settings. A secret aborts before publishing a snapshot."""
    if output.exists():
        raise ValueError("Eksport wymaga nowego katalogu: " + str(output))
    items = {i["source"]: i for i in entries(source, layout) if "source" in i}
    copied, absent = {}, []
    for name, item in items.items():
        path = item["path"]
        data = item["data"]
        if item.get("link"):
            # Export only reviewed source defaults for links; never read an
            # arbitrary destination such as a key or an external profile.
            absent.append(str(path))
            copied[name] = data
            continue
        if name != "hypr/local.lua" and path.exists():
            data = path.read_bytes()
        elif name != "hypr/local.lua":
            absent.append(str(path))
        if name == "apps/zen/user.js" and path.with_name("prefs.js").is_file():
            # prefs.js may contain tokens. Only these already reviewed names
            # can cross the export boundary, irrespective of newly added prefs.
            def preferences(raw):
                result = {}
                for line in raw.decode().splitlines():
                    match = re.fullmatch(r'user_pref\((".*?"), (.*)\);', line)
                    if match:
                        result[json.loads(match[1])] = json.loads(match[2])
                return result
            allowed = preferences(item["data"])
            current = preferences(path.with_name("prefs.js").read_bytes())
            allowed.update({k: current[k] for k in allowed if k in current})
            data = ("// Portable browser preferences.\n" + "".join(
                f"user_pref({json.dumps(k)}, {json.dumps(v)});\n" for k, v in sorted(allowed.items()))).encode()
        if name == "putkin/signal.json":
            value = json.loads(data)
            data = (json.dumps({k: value[k] for k in ("v", "enabled", "deviceName", "typingIndicators") if k in value}, indent=2) + "\n").encode()
        if name == "putkin/launch.json":
            value = json.loads(data)
            wallpaper = value.get("wallpaper", "")
            prefix = str(layout["entry"].parent.parent) + "/"
            if wallpaper.startswith(prefix):
                value["wallpaper"] = "$XDG_CONFIG_HOME/" + wallpaper.removeprefix(prefix)
            elif wallpaper and not wallpaper.startswith("$XDG_CONFIG_HOME/"):
                raise ValueError("Tapeta eksportu musi należeć do konfiguracji: przenieś ją do hypr/backgrounds i dodaj do catalog.json.")
            data = (json.dumps(value, indent=2) + "\n").encode()
        if name == "apps/gnupg/gpg-agent.conf":
            data = data.replace(str(layout["entry"].parent.parent).encode(), b"@XDG_CONFIG_HOME@")
        check_content(name, data)
        copied[name] = data
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".putkin-export-", dir=output.parent) as directory:
        stage = Path(directory) / "config"
        stage.mkdir(mode=0o700)
        for name, data in copied.items():
            atomic_file(stage / name, data)
        atomic_file(stage / "catalog.json", (source / "catalog.json").read_bytes())
        os.replace(stage, output)
    return {"output": str(output), "files": len(copied), "absentUsingDefaults": absent}
