local function number_or_zero(value)
    return tonumber(value) or 0
end

local function toggle_floating_fitted()
    local window = hl.get_active_window()
    local monitor = hl.get_active_monitor()

    if window == nil or monitor == nil then
        return
    end

    local was_tiled = not window.floating
    hl.dispatch(hl.dsp.window.float({ window = window, action = "toggle" }))

    if not was_tiled then
        return
    end

    local gaps = hl.get_config("general.gaps_out") or {}
    local reserved = monitor.reserved or {}
    local border = number_or_zero(hl.get_config("general.border_size"))
    -- Monitor dimensions are physical pixels; window geometry uses logical pixels.
    local scale = tonumber(monitor.scale) or 1

    local left = number_or_zero(reserved.left) + number_or_zero(gaps.left) + border
    local top = number_or_zero(reserved.top) + number_or_zero(gaps.top) + border
    local available_width = number_or_zero(monitor.width) / scale
        - number_or_zero(reserved.left)
        - number_or_zero(reserved.right)
        - number_or_zero(gaps.left)
        - number_or_zero(gaps.right)
        - 2 * border
    local available_height = number_or_zero(monitor.height) / scale
        - number_or_zero(reserved.top)
        - number_or_zero(reserved.bottom)
        - number_or_zero(gaps.top)
        - number_or_zero(gaps.bottom)
        - 2 * border

    local width = math.max(1, math.floor(available_width * 0.95))
    local height = math.max(1, math.floor(available_height * 0.95))

    hl.dispatch(hl.dsp.window.resize({
        window = window,
        x = width,
        y = height,
        relative = false,
    }))
    hl.dispatch(hl.dsp.window.move({
        window = window,
        x = math.floor(number_or_zero(monitor.x) + left + (available_width - width) / 2),
        y = math.floor(number_or_zero(monitor.y) + top + (available_height - height) / 2),
        relative = false,
    }))
end

return function(bindings)
    local bind, main_mod = bindings.bind, "SUPER"
    local close_window_bind = bind(
        main_mod .. " + C",
        hl.dsp.window.close(),
        { description = "[Window] Close" },
        "close window"
    )
    -- close_window_bind:set_enabled(false)

    bind(main_mod .. " + ALT + Q", hl.dsp.exit(), { description = "[Session] Exit Hyprland" }, "exit Hyprland")
    bind(main_mod .. " + F", toggle_floating_fitted, { description = "[Window] Toggle fitted floating" }, "toggle fitted floating")
    bind(main_mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }), { description = "[Window] Toggle fullscreen" }, "toggle fullscreen")
    bind(main_mod .. " + P", hl.dsp.window.pseudo(), { description = "[Window] Toggle pseudo-tiling" }, "toggle pseudo-tiling")
    bind(main_mod .. " + S", hl.dsp.layout("togglesplit"), { description = "[Layout] Toggle split" }, "toggle split")

    bind(main_mod .. " + h", hl.dsp.focus({ direction = "left" }), { description = "[Focus] Left" }, "focus left")
    bind(main_mod .. " + l", hl.dsp.focus({ direction = "right" }), { description = "[Focus] Right" }, "focus right")
    bind(main_mod .. " + k", hl.dsp.focus({ direction = "up" }), { description = "[Focus] Up" }, "focus up")
    bind(main_mod .. " + j", hl.dsp.focus({ direction = "down" }), { description = "[Focus] Down" }, "focus down")

    bind(main_mod .. " + mouse:272", hl.dsp.window.resize(), { mouse = true, description = "[Mouse] Resize window" }, "resize window with left button")
    bind(main_mod .. " + SHIFT + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "[Mouse] Move window" }, "drag window")
    bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "[Mouse] Resize window" }, "resize window")

end
