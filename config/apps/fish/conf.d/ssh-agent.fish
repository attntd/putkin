set -l putkin_config "$HOME/.config"
if set -q XDG_CONFIG_HOME; set putkin_config "$XDG_CONFIG_HOME"; end
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
set -gx SSH_ASKPASS "$putkin_config/quickshell/services/askpass.py"
set -gx SUDO_ASKPASS "$putkin_config/quickshell/services/askpass.py"
