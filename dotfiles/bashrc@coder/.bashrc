# ~/.bashrc — Coder fallback shell adapter

# cmux reconnects can leave mouse reporting enabled in the replacement shell.
case $- in
  *i*) printf '\033[?1000l\033[?1002l\033[?1003l\033[?1005l\033[?1006l\033[?1015l\033[?1016l' > /dev/tty 2>/dev/null || true ;;
esac

: "${ENV_DIR:=${ENV_NEXT_DIR:-$HOME/.config/env}}"
[ -r "$ENV_DIR/profile.sh" ] && . "$ENV_DIR/profile.sh"
