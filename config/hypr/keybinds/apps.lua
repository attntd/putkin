return function(bindings)
    bindings.commands({
        ["kitty"] = "SUPER + RETURN",
        ["zen-browser"] = "SUPER + SHIFT + RETURN",
        file_manager = { command = "kitty -e fish -lc yazi", bind = "SUPER + E", description = "[Apps] Yazi" },
        dictation = { command = "voxtype record toggle", bind = "SUPER + SHIFT + code:201", description = "[Apps] Voxtype" },
    })
end
