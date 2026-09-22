return function(bindings)
    local bind = bindings.bind
    local paths = require("lib.paths")
    bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(paths.ipc .. "audio changeVolume 5"), { repeating = true, description = "[Hardware] Volume up" }, "volume up")
    bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(paths.ipc .. "audio changeVolume -5"), { repeating = true, description = "[Hardware] Volume down" }, "volume down")
    bind("XF86AudioMute", hl.dsp.exec_cmd(paths.ipc .. "audio toggleMute"), { repeating = true, description = "[Hardware] Toggle audio mute" }, "toggle audio mute")
    bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true, description = "[Hardware] Toggle microphone mute" }, "toggle microphone mute")
    bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(paths.ipc .. "brightness change 5"), { repeating = true, description = "[Hardware] Brightness up" }, "brightness up")
    bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(paths.ipc .. "brightness change -5"), { repeating = true, description = "[Hardware] Brightness down" }, "brightness down")

    bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "[Media] Next" }, "next media")
    bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "[Media] Play or pause" }, "pause media")
    bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "[Media] Play or pause" }, "play media")
    bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "[Media] Previous" }, "previous media")

end
