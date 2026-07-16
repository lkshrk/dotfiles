# Interactive SSH sessions land in a shared tmux session.
if [[ -z "$TMUX" && -n "$SSH_TTY" ]] && command -v tmux >/dev/null 2>&1; then
  if tmux has-session -t default 2>/dev/null; then
    exec tmux attach-session -t default
  else
    exec tmux new-session -s default
  fi
fi
