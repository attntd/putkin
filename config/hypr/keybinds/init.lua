local bindings = require("lib.bindings")
for _, module in ipairs({"apps", "windows", "workspaces", "hardware", "shell"}) do
    require("keybinds." .. module)(bindings)
end
