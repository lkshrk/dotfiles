# Interactive SSH sessions land in a shared tmux session.
if [[ -z "$TMUX" && -n "$SSH_TTY" ]] && command -v tmux >/dev/null 2>&1; then
  tmux new-session -A -s default
fi
