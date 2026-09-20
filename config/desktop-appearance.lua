-- Optional Putkin appearance fragment for Hyprland 0.56.2 (Lua).
-- Load AFTER your appearance settings with dofile("/absolute/path/to/this/file").
-- Rollback: remove that dofile and reload your original configuration.
-- No autostart, key bindings, monitor rules or application settings.
-- Startup fallback. Putkin synchronizes the current Theme while running.
local active_colors = {}
for step = 0, 9 do
    local t = step / 9
    active_colors[#active_colors + 1] = string.format("rgba(%02x%02x%02xff)",
        math.floor(203 + (137 - 203) * t + 0.5),
        math.floor(166 + (180 - 166) * t + 0.5),
        math.floor(247 + (250 - 247) * t + 0.5))
end
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 2,
        col = {
            -- sin(30°) gives both normalized axes equal weight in Hyprland.
            active_border = { colors = active_colors, angle = 30 },
            inactive_border = "rgba(45475aff)",
        },
    },
    decoration = {
        rounding = 0,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        blur = { enabled = false },
        shadow = { enabled = false },
    },
})

-- Putkin animates opacity itself, including the reduced-motion setting.
-- Prevent the compositor from animating layer size/position a second time.
hl.layer_rule({
    name = "putkin-surfaces",
    match = { namespace = "^putkin-(bar|panel|osd|notifications|wallpaper)$" },
    no_anim = true,
})
