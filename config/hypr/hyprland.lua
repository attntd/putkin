-- Wspólne ustawienia; własne nadpisania komputera są w local.lua.
local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local directory = config .. "/hypr"
package.path = directory .. "/?.lua;" .. directory .. "/?/init.lua;" .. package.path
for _, module in ipairs({"environment", "input", "appearance", "animations", "layout", "rules", "permissions", "keybinds", "autostart"}) do
    require(module)
end
-- Domyślny wybór działa także bez monitorów poprzedniego komputera.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
dofile(directory .. "/local.lua")
