#!/bin/sh
# Waits a full interval after the server starts so a save cannot overwrite the snapshot being restored.
set -eu

start=$(tmux display -p '#{start_time}' 2>/dev/null) || exit 0
[ $(($(date +%s) - start)) -ge 300 ] || exit 0
exec "$HOME/.local/share/tmux/plugins/tmux-resurrect/scripts/save.sh" quiet
