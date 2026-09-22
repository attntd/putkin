hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true })
for _, app in ipairs({"kitty", "zen"}) do
    hl.window_rule({ name = app .. "-focus-on-activate", match = { class = "^" .. app .. "$" }, focus_on_activate = true })
end
hl.window_rule({ name = "move-hyprland-run", match = { class = "hyprland-run" }, move = "20 monitor_h-120", float = true })
local paths = require("lib.paths")
dofile(paths.shell .. "/config/shell-layers.lua")
