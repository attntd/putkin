-- Wygląd okien. Akcenty ramek aktualizuje działający Putkin.
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 2,

        col = {
            -- Putkin startup palette; the running shell synchronizes theme changes.
            active_border   = { colors = {"rgba(cba6f7ff)", "rgba(c4a8f7ff)", "rgba(bca9f8ff)", "rgba(b5abf8ff)", "rgba(aeacf8ff)", "rgba(a6aef9ff)", "rgba(9faff9ff)", "rgba(98b1f9ff)", "rgba(90b2faff)", "rgba(89b4faff)"}, angle = 30 },
            inactive_border = "rgba(45475aff)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 0,
        rounding_power = 5,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 0.94,
        inactive_opacity = 0.90,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 6,
            passes    = 2,
            new_optimizations = true,
            ignore_opacity = true,
            noise     = 0.02,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

