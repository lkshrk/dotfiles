# Clear mouse modes left behind when cmux replaces a disconnected session.
if [[ -n "${CMUX_WORKSPACE_ID:-}" ]]; then
  printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l' > /dev/tty 2>/dev/null || true
fi

# Interactive Coder terminals (including browser terminals, which do not set
# SSH_TTY) land in a shared tmux session. Avoid nesting when the caller is
# already inside tmux.
if [[ -o interactive && -z "$TMUX" && ( -n "$SSH_TTY" || -n "${CODER_WORKSPACE_NAME:-}" ) ]] \
  && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s default
fi
