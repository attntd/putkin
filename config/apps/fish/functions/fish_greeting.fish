function fish_greeting
    set -l update_cache_root "$HOME/.cache"
    if set -q XDG_CACHE_HOME
        set update_cache_root "$XDG_CACHE_HOME"
    end
    set -l update_cache "$update_cache_root/fish/update-status.fish"

    if not test -r "$update_cache"
        set_color a6adc8
        echo "󰏗 Oczekiwanie na pierwsze sprawdzenie aktualizacji"
        set_color normal
        return
    end

    source "$update_cache"
    set -l update_total (math "$__update_repo + $__update_aur")

    if test "$__update_status" != ok
        set_color f9e2af
        echo "󰏗 Aktualizacje: repo $__update_repo, AUR $__update_aur (częściowy wynik)"
    else if test "$update_total" -gt 0
        set_color f9e2af
        echo "󰏗 Dostępnych aktualizacji: $update_total (repo: $__update_repo, AUR: $__update_aur)"
    else
        set_color a6e3a1
        echo "󰄬 System jest aktualny"
    end

    set_color normal
    set -e __update_repo __update_aur __update_checked_at __update_status
end
