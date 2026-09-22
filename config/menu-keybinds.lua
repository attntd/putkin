-- Hyprland 0.56.2. Pass the registry's bind and the installed shell.qml path.
return function(bind, shell_path)
    assert(type(shell_path) == "string" and shell_path:sub(1, 1) == "/",
        "Putkin requires an absolute shell.qml path")
    assert(not shell_path:find("%z") and not shell_path:find("\n"),
        "Invalid Putkin path")
    local quoted_path = "'" .. shell_path:gsub("'", "'\\''") .. "'"
    local ipc = "quickshell ipc --path " .. quoted_path .. " call "
    local menus = {
        {"SUPER + SPACE", "launcher"},
        {"SUPER + V", "clipboard"},
        {"SUPER + semicolon", "commands"},
        {"SUPER + B", "bar"},
        {"SUPER + Q", "quickSettings"},
        {"SUPER + SHIFT + P", "power"},
        {"SUPER + SHIFT + N", "notifications"},
    }
    _G.putkin_handles = {}
    _G.putkin_shortcuts = {}
    for _, menu in ipairs(menus) do
        local command = ipc .. "actions invoke " .. menu[2]
        local handle = bind(menu[1], hl.dsp.exec_cmd(command), {description = "Putkin:" .. menu[2]})
        table.insert(_G.putkin_handles, handle)
        table.insert(_G.putkin_shortcuts, {key = menu[1], action = menu[2], command = command})
    end
    bind("SUPER + SHIFT + B", hl.dsp.exec_cmd(ipc .. "bar focus"), {description = "[Putkin] Pasek"})
end
