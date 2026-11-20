#!/bin/sh
# Drops the session that started the server when continuum restores beside it: absent from the save, one shell pane, created with the server.
set -u

dir=$(tmux show -gqv @resurrect-dir)
dir=${dir:-$HOME/.tmux/resurrect}
case $dir in "~"/*) dir=$HOME/${dir#"~"/} ;; esac
save="$dir/last"
[ -r "$save" ] || exit 0

saved=$(awk -F'\t' '$1 == "pane" {print $2}' "$save" | sort -u)
active=$(awk -F'\t' '$1 == "state" {print $2; exit}' "$save")
start=$(tmux display -p '#{start_time}')
total=$(tmux list-sessions | wc -l)

tmux list-sessions -F "#{session_name}	#{session_created}	#{session_windows}" |
  while IFS='	' read -r name created windows; do
    printf '%s\n' "$saved" | grep -qxF -- "$name" && continue
    [ "$windows" = 1 ] && [ $((created - start)) -le 30 ] && [ "$total" -gt 1 ] || continue
    panes=$(tmux list-panes -s -t "=$name" -F '#{pane_current_command}')
    [ "$(printf '%s\n' "$panes" | wc -l)" = 1 ] || continue
    case $panes in zsh | bash | sh | fish) ;; *) continue ;; esac
    target=$active
    tmux has-session -t "=$target" 2>/dev/null || target=$(printf '%s\n' "$saved" | head -1)
    for client in $(tmux list-clients -t "=$name" -F '#{client_name}'); do
      tmux switch-client -c "$client" -t "=$target"
    done
    tmux kill-session -t "=$name"
    total=$((total - 1))
  done
