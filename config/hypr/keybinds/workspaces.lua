return function(bindings)
    local bind, main_mod = bindings.bind, "SUPER"
    for workspace = 1, 10 do
        local key = workspace % 10
        bind(
            main_mod .. " + " .. key,
            hl.dsp.focus({ workspace = workspace }),
            { description = "[Workspace] Focus " .. workspace },
            "focus workspace " .. workspace
        )
        bind(
            main_mod .. " + SHIFT + " .. key,
            hl.dsp.window.move({ workspace = workspace }),
            { description = "[Workspace] Move window to " .. workspace },
            "move window to workspace " .. workspace
        )
    end

    bind(main_mod .. " + M", hl.dsp.workspace.toggle_special("magic"), { description = "[Workspace] Toggle magic" }, "toggle magic workspace")
    bind(main_mod .. " + SHIFT + M", hl.dsp.window.move({ workspace = "special:magic" }), { description = "[Workspace] Move window to magic" }, "move window to magic workspace")

    bind("SHIFT + ALT + M", function()
        local active_window = hl.get_active_window()
        local regular_workspace = hl.get_active_workspace()

        if active_window == nil or active_window.workspace == nil or regular_workspace == nil then
            return
        end
        if active_window.workspace.name ~= "special:magic" then
            return
        end

        hl.dispatch(hl.dsp.window.move({
            window = active_window,
            workspace = regular_workspace,
            follow = true,
        }))
    end, { description = "[Workspace] Return window from magic" }, "return window from magic workspace")

    bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "[Workspace] Next" }, "next workspace")
    bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "[Workspace] Previous" }, "previous workspace")

end
