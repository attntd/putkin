"""Run the binding adapter's conflict handling and emitted Lua transactions."""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("putkin_keyboard", ROOT / "services/keyboard.py")
keyboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(keyboard)


class KeyboardTest(unittest.TestCase):
    def test_conflicts_include_case_aliases_and_physical_keys(self):
        rows = [{"action": "settings", "shortcut": "SUPER + H"}]
        for bind, codes in [
            ({"key": "h", "modmask": 64, "description": "Focus left"}, {}),
            ({"key": "", "keycode": 43, "modmask": 64, "description": "Physical H"}, {43: {keyboard.symbol("h")}}),
        ]:
            with self.subTest(bind=bind), self.assertRaisesRegex(ValueError, "Konflikt"):
                keyboard.validate(rows, [bind], codes)
        keyboard.validate(rows, [{"key": "h", "modmask": 65, "description": "Other modifiers"}])

    def test_own_keys_can_be_changed_but_shared_submap_keys_are_protected(self):
        owned = {"key": "H", "modmask": 64, "description": "Putkin:settings"}
        keyboard.validate([{"action": "settings", "shortcut": "SUPER + J"}], [owned])
        with self.assertRaisesRegex(ValueError, "Konflikt"):
            keyboard.validate([], [owned, {"key": "h", "modmask": 64, "description": "Foreign submap", "submap": "resize"}])

    def test_duplicate_and_invalid_shortcuts(self):
        for value in ["SUPER + SUPER + H", "SUPER + NopeKey", "h", "SUPER + ; os.execute('false')", "SUPER + H\n"]:
            if value.endswith("\n"):
                continue  # outer whitespace is intentionally normalized
            with self.subTest(value=value), self.assertRaises(ValueError):
                keyboard.shortcut(value)
        with self.assertRaisesRegex(ValueError, "Powtórzony"):
            keyboard.validate([{"action": "settings", "shortcut": "SUPER + H"}, {"action": "audio", "shortcut": "SUPER + h"}], [])
        self.assertEqual(keyboard.shortcut("SUPER + SHIFT + semicolon")[0], 65)
        self.assertEqual(keyboard.shortcut("Print"), (0, keyboard.symbol("Print")))

    def test_lua_rebinds_remove_old_keys_without_accumulation(self):
        first = [{"action": "settings", "shortcut": "SUPER + ALT + U"}]
        second = [{"action": "audio", "shortcut": "SUPER + ALT + A"}]
        path = "/tmp/żółć '$HOME `id`/shell.qml"
        script = '''
local registered = {}
hl = {dsp = {exec_cmd = function(command) return command end}}
function hl.bind(key, command, options)
  assert(not registered[key], "duplicate")
  local handle = {command = command, description = options.description}
  function handle:remove() registered[key] = nil end
  registered[key] = handle
  return handle
end
'''
        for rows in [first, first, second, second]:
            script += "do local apply = function()\n" + keyboard.apply_script(rows, path) + "\nend; assert(apply() == 'putkin-ok') end\n"
        script += '''
assert(registered["SUPER + ALT + U"] == nil)
assert(registered["SUPER + ALT + A"].description == "Putkin:audio")
local count = 0; for _ in pairs(registered) do count = count + 1 end
assert(count == 1)
io.write(registered["SUPER + ALT + A"].command)
'''
        result = subprocess.run(["lua", "-"], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        import shlex
        self.assertEqual(shlex.split(result.stdout), ["quickshell", "ipc", "--path", path, "call", "actions", "invoke", "audio"])

    def test_lua_registration_failure_restores_previous(self):
        first = [{"action": "settings", "shortcut": "SUPER + ALT + U"}]
        bad = [{"action": "audio", "shortcut": "SUPER + ALT + A"}]
        script = '''
local registered = {}
hl = {dsp = {exec_cmd = function(command) return command end}}
function hl.bind(key, command, options)
  if key == "SUPER + ALT + A" then error("denied") end
  local h = {}; function h:remove() registered[key] = nil end
  registered[key] = h; return h
end
local initial = function()
''' + keyboard.apply_script(first, "/tmp/shell.qml") + "\nend; initial()\nlocal failure = function()\n" + keyboard.apply_script(bad, "/tmp/shell.qml") + '''
end
assert(not pcall(failure))
assert(registered["SUPER + ALT + U"])
assert(not registered["SUPER + ALT + A"])
'''
        result = subprocess.run(["lua", "-"], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_preflight_is_read_only_and_refusal_prevents_apply(self):
        request = {"operation": "check", "shell": "/tmp/shell.qml", "bindings": [{"action": "settings", "shortcut": "SUPER + U"}]}
        with patch.object(keyboard, "run", return_value="[]") as run:
            keyboard.process(request)
            run.assert_called_once_with("-j", "binds")
        request["operation"] = "apply"
        with patch.object(keyboard, "run", return_value=json.dumps([{"key": "U", "modmask": 64, "description": "Foreign"}])) as run:
            with self.assertRaisesRegex(ValueError, "Konflikt"):
                keyboard.process(request)
            run.assert_called_once_with("-j", "binds")


if __name__ == "__main__":
    unittest.main()
