#!/usr/bin/env python3
"""Finite, one-shot Hyprland 0.56 Lua binding adapter. JSON in/out; no daemon."""
import ctypes
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys

PREFIX = "Putkin:"
MODS = {"SUPER": 64, "CONTROL": 4, "ALT": 8, "SHIFT": 1}


def run(*args):
    result = subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=5)
    if result.returncode:
        raise ValueError("Hyprland niedostępny.")
    return result.stdout.strip()


def symbol(key):
    lib = ctypes.CDLL("libxkbcommon.so.0")
    lib.xkb_keysym_from_name.argtypes = [ctypes.c_char_p, ctypes.c_int]
    lib.xkb_keysym_from_name.restype = ctypes.c_uint32
    lib.xkb_keysym_to_lower.argtypes = [ctypes.c_uint32]
    lib.xkb_keysym_to_lower.restype = ctypes.c_uint32
    return lib.xkb_keysym_to_lower(lib.xkb_keysym_from_name(key.encode("ascii"), 1))


def shortcut(value):
    parts = [part.strip() for part in value.split("+")]
    key = parts.pop()
    if not re.fullmatch(r"[A-Za-z0-9_]+", key) or any(part not in MODS for part in parts) or len(parts) != len(set(parts)):
        raise ValueError("Niepoprawny skrót: " + value)
    if not parts and not re.fullmatch(r"F(?:[1-9]|[12][0-9]|3[0-5])|XF86[A-Za-z0-9]+|Print", key):
        raise ValueError("Skrót wymaga modyfikatora: " + value)
    sym = symbol(key)
    if not sym:
        raise ValueError("Nieznany klawisz: " + key)
    return sum(MODS[part] for part in parts), sym


def keycodes():
    # Match physical-code binds as well as symbols, using the compositor's map.
    lib = ctypes.CDLL("libxkbcommon.so.0")
    class Names(ctypes.Structure):
        _fields_ = [(name, ctypes.c_char_p) for name in ("rules", "model", "layout", "variant", "options")]
    lib.xkb_context_new.argtypes = [ctypes.c_int]
    lib.xkb_context_new.restype = ctypes.c_void_p
    lib.xkb_keymap_new_from_names.argtypes = [ctypes.c_void_p, ctypes.POINTER(Names), ctypes.c_int]
    lib.xkb_keymap_new_from_names.restype = ctypes.c_void_p
    lib.xkb_keymap_min_keycode.argtypes = lib.xkb_keymap_max_keycode.argtypes = [ctypes.c_void_p]
    lib.xkb_keymap_key_get_syms_by_level.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(ctypes.POINTER(ctypes.c_uint32))]
    lib.xkb_context_unref.argtypes = lib.xkb_keymap_unref.argtypes = [ctypes.c_void_p]
    values = [json.loads(run("-j", "getoption", "input:kb_" + name)).get("str", "").encode() or None for name in ("model", "layout", "variant", "options")]
    names = Names(None, *values)
    context = lib.xkb_context_new(0)
    keymap = lib.xkb_keymap_new_from_names(context, ctypes.byref(names), 0)
    if not keymap:
        lib.xkb_context_unref(context)
        raise ValueError("Nie można odczytać mapy klawiatury Hyprlanda.")
    result = {}
    try:
        for code in range(lib.xkb_keymap_min_keycode(keymap), lib.xkb_keymap_max_keycode(keymap) + 1):
            syms = ctypes.POINTER(ctypes.c_uint32)()
            count = lib.xkb_keymap_key_get_syms_by_level(keymap, code, 0, 0, ctypes.byref(syms))
            result[code] = set(syms[i] for i in range(count))
    finally:
        lib.xkb_keymap_unref(keymap)
        lib.xkb_context_unref(context)
    return result


def validate(rows, current, codes=None):
    seen = set()
    for row in rows:
        if not isinstance(row, dict) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9]*", row.get("action", "")):
            raise ValueError("Niepoprawne działanie.")
        key = row.get("shortcut", "")
        if not key:
            continue
        mask, sym = shortcut(key)
        if (mask, sym) in seen:
            raise ValueError("Powtórzony skrót: " + key)
        seen.add((mask, sym))
    # remove() also matches keys in other submaps, so protect old owned keys too.
    owned = {(b["modmask"], symbol(b["key"])) for b in current if b.get("description", "").startswith(PREFIX) and b.get("key")}
    for bind in current:
        if bind.get("description", "").startswith(PREFIX):
            continue
        symbols = {symbol(bind["key"])} if bind.get("key") else (codes or {}).get(bind.get("keycode"), set())
        if any((bind["modmask"], sym) in seen | owned for sym in symbols):
            raise ValueError("Konflikt skrótu: " + (bind.get("description") or bind.get("key") or str(bind.get("keycode"))))


def lua_string(value):
    # Byte escapes work in Lua 5.4, including UTF-8 paths and non-ASCII names.
    return '"' + ''.join(chr(b) if 32 <= b <= 126 and b not in (34, 92) else f"\\{b:03d}" for b in value.encode()) + '"'


def apply_script(rows, shell):
    specs = []
    for row in rows:
        if not row["shortcut"]:
            continue
        command = shlex.join(["quickshell", "ipc", "--path", shell, "call", "actions", "invoke", row["action"]])
        specs.append("{key=" + lua_string(row["shortcut"]) + ",command=" + lua_string(command) + ",action=" + lua_string(row["action"]) + "}")
    return """
local next = {SPECS}
local previous = _G.putkin_shortcuts or {}
local function install(specs)
    for _, handle in ipairs(_G.putkin_handles or {}) do handle:remove() end
    _G.putkin_handles = {}
    for _, spec in ipairs(specs) do
        local handle = hl.bind(spec.key, hl.dsp.exec_cmd(spec.command), {description = "Putkin:" .. spec.action})
        assert(handle, "binding registration failed")
        table.insert(_G.putkin_handles, handle)
    end
    _G.putkin_shortcuts = specs
end
local ok, err = pcall(install, next)
if not ok then pcall(install, previous); error(err) end
return "putkin-ok"
""".replace("SPECS", ",".join(specs))


def process(request):
    rows = request["bindings"]
    if not isinstance(rows, list) or len(rows) > 100:
        raise ValueError("Niepoprawna lista skrótów.")
    shell = request["shell"]
    if not isinstance(shell, str) or not Path(shell).is_absolute() or any(c in shell for c in "\x00\r\n"):
        raise ValueError("Niepoprawna ścieżka shella.")
    current = json.loads(run("-j", "binds"))
    codes = keycodes() if any(bind.get("keycode", 0) for bind in current) else {}
    validate(rows, current, codes)
    if request["operation"] == "check":
        return
    if request["operation"] != "apply":
        raise ValueError("Nieznana operacja klawiatury.")
    result = run("eval", apply_script(rows, shell))
    if result != "ok" and "putkin-ok" not in result:
        raise ValueError("Hyprland odrzucił skróty: " + result[:400])
    observed = json.loads(run("-j", "binds"))
    expected = {(PREFIX + row["action"], *shortcut(row["shortcut"])) for row in rows if row["shortcut"]}
    actual = {(bind["description"], bind["modmask"], symbol(bind["key"])) for bind in observed if bind.get("description", "").startswith(PREFIX)}
    if actual != expected or len([b for b in observed if b.get("description", "").startswith(PREFIX)]) != len(expected):
        raise ValueError("Nie potwierdzono aktywacji skrótów.")


def main():
    try:
        raw = sys.stdin.read(65537)
        if len(raw) > 65536:
            raise ValueError("Zbyt duża konfiguracja klawiatury.")
        process(json.loads(raw))
        print(json.dumps({"error": ""}))
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({"error": str(error)}, ensure_ascii=False))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
