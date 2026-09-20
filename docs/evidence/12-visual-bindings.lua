local plan_dir = "/tmp/putkin-visual-stage/"
local bindings_seen = {}
local function proxy(path)
    return setmetatable({}, {
        __index = function(_, name) return proxy(path .. "." .. name) end,
        __call = function(_, ...) return {api = path, args = {...}} end,
    })
end
hl = proxy("hl")
hl.bind = function(key, dispatcher, options)
    assert(not bindings_seen[key], "Duplicate bind: " .. key)
    bindings_seen[key] = {dispatcher = dispatcher, options = options or {}}
    return {}
end
local bindings = dofile(os.getenv("HOME") .. "/.config/hypr/modules/bindings.lua")
bindings.commands(dofile(os.getenv("HOME") .. "/.config/hypr/keybinds.lua"))
dofile(plan_dir .. "after/2").setup(bindings)
local shell_path = "/home/attntd/.local/share/putkin/releases/20260916-visual-3d0c562aa347/shell.qml"
dofile(plan_dir .. "runtime/config/menu-keybinds.lua")(bindings.bind, shell_path)
for _, key in ipairs({"SUPER + B", "SUPER + SHIFT + Q", "SUPER + SHIFT + P", "SUPER + N", "SUPER + TAB", "XF86AudioRaiseVolume", "XF86AudioLowerVolume", "XF86AudioMute", "XF86MonBrightnessUp", "XF86MonBrightnessDown"}) do
    local value = assert(bindings_seen[key], key)
    assert(value.dispatcher.api == "hl.dsp.exec_cmd")
    assert(value.dispatcher.args[1]:find(shell_path, 1, true))
    assert(not value.options.locked)
end
assert(bindings_seen["SUPER + SHIFT + L"].dispatcher.args[1] == "env PUTKIN_WALLPAPER=/home/attntd/.config/hypr/backgrounds/Cloudsnight.jpg /home/attntd/.local/share/putkin/releases/20260916-visual-3d0c562aa347/scripts/lock-session")
assert(bindings_seen["SUPER + RETURN"].dispatcher.args[1] == "kitty")
local quoted
local weird = "/tmp/space and ' apostrophe/shell.qml"
dofile(plan_dir .. "runtime/config/menu-keybinds.lua")(function(_, cmd) quoted = cmd.args[1] end, weird)
assert(quoted:find("'\\''", 1, true))
assert(not pcall(dofile(plan_dir .. "runtime/config/menu-keybinds.lua"), function() end, "relative.qml"))
local autostart
hl.on = function(name, callback) assert(name == "hyprland.start"); callback() end
hl.exec_cmd = function(cmd) autostart = cmd end
dofile(plan_dir .. "after/0")
assert(autostart:find(shell_path, 1, true))
assert(autostart:find("--no-duplicate", 1, true))
local count = 0
for _ in pairs(bindings_seen) do count = count + 1 end
print("PASS: " .. count .. " bindings, no duplicates; Putkin commands, new lock wrapper/terminal preserved, quoted paths, autostart")
