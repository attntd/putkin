local seen = {}
local function proxy(path)
 return setmetatable({}, {__index=function(_,key) return proxy(path .. "." .. key) end,
 __call=function(_,...) return {api=path,args={...}} end})
end
hl=proxy("hl")
hl.bind=function(key,dispatcher,options)
 assert(not seen[key], "duplicate binding: " .. key)
 seen[key]={dispatcher=dispatcher, options=options or {}}
 return {remove=function() seen[key]=nil end}
end
local bindings=dofile("/home/attntd/.config/hypr/modules/bindings.lua")
bindings.commands(dofile("/home/attntd/.config/hypr/keybinds.lua"))
dofile("/tmp/putkin-settings-keyboard-update/config-2").setup(bindings)
local shell_path="/home/attntd/.local/share/putkin/releases/20260917-settings-keyboard-cc7addc79750/shell.qml"
local menu=dofile("/tmp/putkin-settings-keyboard-update/runtime/config/menu-keybinds.lua")
menu(bindings.bind,shell_path)
for _,spec in ipairs({{"SUPER + SPACE","actions invoke launcher"},{"SUPER + V","actions invoke clipboard"},{"SUPER + SHIFT + semicolon","actions invoke commands"}}) do
 local actual=assert(seen[spec[1]],spec[1])
 assert(actual.dispatcher.api=="hl.dsp.exec_cmd")
 assert(actual.dispatcher.args[1]=="quickshell ipc --path '"..shell_path.."' call "..spec[2])
 assert(not actual.options.locked)
end
assert(seen["SUPER + RETURN"].dispatcher.args[1]=="kitty")
assert(seen["SUPER + SHIFT + L"].dispatcher.args[1]:find("20260917-icons-cd3b25f5725c/scripts/lock-session",1,true))
local quoted
menu(function(_,cmd) quoted=cmd.args[1] end,"/tmp/space and ' quote/shell.qml")
assert(quoted:find("'\\''",1,true))
assert(not pcall(menu,function() end,"relative.qml"))
local autostart
hl.on=function(_,cb) cb() end
hl.exec_cmd=function(cmd) autostart=cmd end
dofile("/tmp/putkin-settings-keyboard-update/config-1")
assert(autostart:find(shell_path,1,true))
local count=0
for _ in pairs(seen) do count=count+1 end
print("PASS: "..count.." bindings; no collisions; launcher/clipboard/commands; lock and terminal preserved; quoting and autostart")
