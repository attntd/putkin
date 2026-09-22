return function(bindings)
    local paths = require("lib.paths")
    dofile(paths.shell .. "/config/menu-keybinds.lua")(bindings.bind, paths.shell .. "/shell.qml")
    local actions = {
        { "SUPER + TAB", "bar focus" },
        { "SUPER + N", "notifications focus" },
        { "SUPER + SHIFT + L", "session lock" },
        { "SHIFT + PRINT", "actions invoke screenshot" },
        { "SUPER + PRINT", "actions invoke screenshot" },
        { "CTRL + PRINT", "actions invoke screenshot" },
        { "SUPER + SHIFT + S", "actions invoke screenshot" },
    }
    for _, action in ipairs(actions) do
        bindings.bind(action[1], hl.dsp.exec_cmd(paths.ipc .. action[2]), {description = "[Putkin] " .. action[2]})
    end
end
