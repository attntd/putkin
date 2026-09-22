local M = {}
M.config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
M.shell = M.config .. "/quickshell"
function M.quote(value)
    assert(not value:find("%z") and not value:find("\n"), "Invalid path")
    return "'" .. value:gsub("'", "'\\''") .. "'"
end
M.ipc = "quickshell ipc --path " .. M.quote(M.shell .. "/shell.qml") .. " call "
return M
