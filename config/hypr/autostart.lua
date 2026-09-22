local paths = require("lib.paths")
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprsunset.service ssh-agent.socket fish-update-check.timer fish-update-check.path voxtype.service")
    -- Jedyny właściciel paska, powiadomień, blokady i Signala.
    hl.exec_cmd(paths.quote(os.getenv("HOME") .. "/.local/bin/qs"))
end)
