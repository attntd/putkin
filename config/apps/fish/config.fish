fish_add_path ~/.local/bin

if status is-interactive

  function fish_user_key_bindings
    fish_vi_key_bindings default
  end

  if type -q starship
    starship init fish | source
  end

end
