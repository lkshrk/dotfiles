#!/usr/bin/env bash
# tmux-save.timer's script saves only a default-socket server that has run for a full interval.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

script="$repo/home/dot_config/tmux/executable_autosave.sh"
save="$tmp/home/.local/share/tmux/plugins/tmux-resurrect/scripts/save.sh"
mkdir -p "$tmp/bin" "$(dirname "$save")"
cat >"$tmp/bin/tmux" <<'EOF'
#!/usr/bin/env bash
[ -n "${SERVER_START:-}" ] || exit 1
[ "$*" = "display -p #{start_time}" ] && echo "$SERVER_START"
EOF
cat >"$save" <<'EOF'
#!/bin/sh
echo "$*" >>"$SAVE_LOG"
EOF
chmod +x "$tmp/bin/tmux" "$save"
export PATH="$tmp/bin:$PATH" HOME="$tmp/home" SAVE_LOG="$tmp/save.log"

sh "$script" || fail "exits non-zero without a server"
[ ! -e "$SAVE_LOG" ] || fail "saved without a server"

SERVER_START=$(($(date +%s) - 60)) sh "$script" || fail "exits non-zero for a young server"
[ ! -e "$SAVE_LOG" ] || fail "saved a server younger than the interval"

SERVER_START=$(($(date +%s) - 301)) sh "$script" || fail "save failed"
[ "$(cat "$SAVE_LOG")" = quiet ] || fail "did not run resurrect's save quietly"

printf 'PASS: tmux autosave skips missing and young servers, saves the rest\n'
