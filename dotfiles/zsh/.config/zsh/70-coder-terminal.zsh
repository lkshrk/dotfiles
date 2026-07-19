if [[ -n ${CODER_WORKSPACE_NAME:-} ]]; then
  _coder_clear_mouse_modes() {
    printf '\033[?1000l\033[?1002l\033[?1003l\033[?1005l\033[?1006l\033[?1015l\033[?1016l' > /dev/tty 2>/dev/null || true
  }

  # Coder reconnects reuse the shell; terminal resize is the reconnect signal.
  TRAPWINCH() {
    _coder_clear_mouse_modes
  }

  _coder_clear_mouse_modes

  if [[ -z ${TMUX:-} ]] && command -v tmux >/dev/null 2>&1; then
    if tmux has-session -t '=default' 2>/dev/null && ! tmux has-session -t '=default-1' 2>/dev/null; then
      tmux rename-session -t '=default' default-1
    fi

    # ponytail: allocation is best-effort; add a startup lock if simultaneous reconnects ever collide.
    _coder_tmux_slot=1
    while true; do
      _coder_tmux_session="default-$_coder_tmux_slot"
      if ! tmux has-session -t "=$_coder_tmux_session" 2>/dev/null; then
        exec tmux new-session -s "$_coder_tmux_session"
      elif [[ $(tmux display-message -p -t "=$_coder_tmux_session" '#{session_attached}') == 0 ]]; then
        exec tmux attach-session -t "=$_coder_tmux_session"
      fi
      (( ++_coder_tmux_slot ))
    done
  fi
fi
