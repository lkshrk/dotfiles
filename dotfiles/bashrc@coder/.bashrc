# ~/.bashrc — Coder fallback shell adapter

# Coder reconnects reuse the shell; terminal resize is the reconnect signal.
_coder_clear_mouse_modes() {
  printf '\033[?1000l\033[?1002l\033[?1003l\033[?1005l\033[?1006l\033[?1015l\033[?1016l' > /dev/tty 2>/dev/null || true
}

case $- in
  *i*) trap _coder_clear_mouse_modes WINCH; _coder_clear_mouse_modes ;;
esac

: "${ENV_DIR:=${ENV_NEXT_DIR:-$HOME/.config/env}}"
[ -r "$ENV_DIR/profile.sh" ] && . "$ENV_DIR/profile.sh"
