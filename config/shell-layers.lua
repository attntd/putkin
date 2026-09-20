-- Hyprland 0.56.2: Putkin owns its fades and reduced-motion behavior.
hl.layer_rule({
    name = "putkin-surfaces",
    match = { namespace = "^putkin-(bar|panel|osd|notifications|wallpaper)$" },
    no_anim = true,
})
hl.window_rule({
    name = "putkin-settings",
    match = { class = "^org.quickshell$", title = "^Ustawienia$" },
    float = true,
    center = true,
    rounding = 0,
})
