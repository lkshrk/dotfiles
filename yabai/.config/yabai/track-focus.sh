#!/usr/bin/env bash
set -euo pipefail

HIST_FILE="${TMPDIR:-/tmp}/yabai_window_focus_history"
mkdir -p "$(dirname "$HIST_FILE")"

if [ -n "${YABAI_WINDOW_ID:-}" ]; then
  printf '%s %s\n' "$(date +%s)" "$YABAI_WINDOW_ID" >> "$HIST_FILE"
  tmp=$(mktemp "${HIST_FILE}.XXXXXX")
  tail -n 5000 "$HIST_FILE" > "$tmp" && mv "$tmp" "$HIST_FILE" || rm -f "$tmp"
fi
