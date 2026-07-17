# Interactive Coder terminals (including browser terminals, which do not set
# SSH_TTY) land in a shared tmux session. Avoid nesting when the caller is
# already inside tmux.
if [[ -o interactive && -z "$TMUX" && ( -n "$SSH_TTY" || -n "${CODER_WORKSPACE_NAME:-}" ) ]] \
  && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s default
fi
