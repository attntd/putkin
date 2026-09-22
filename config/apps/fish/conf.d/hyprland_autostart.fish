if status is-login; and status is-interactive
  if uwsm check may-start -q
    exec uwsm start -e -D Hyprland hyprland.desktop
  end
end
