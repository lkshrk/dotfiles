if [[ -n ${CODER_WORKSPACE_NAME:-} ]]; then
  _coder_clear_mouse_modes() {
    printf '\033[?1000l\033[?1002l\033[?1003l\033[?1005l\033[?1006l\033[?1015l\033[?1016l' > /dev/tty 2>/dev/null || true
  }

  # Coder reconnects reuse the shell; terminal resize is the reconnect signal.
  TRAPWINCH() {
    _coder_clear_mouse_modes
  }

  _coder_clear_mouse_modes
fi
