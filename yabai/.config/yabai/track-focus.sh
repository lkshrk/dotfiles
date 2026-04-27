#!/usr/bin/env bash
set -euo pipefail

HIST_FILE="${TMPDIR:-/tmp}/yabai_window_focus_history"
mkdir -p "$(dirname "$HIST_FILE")"

if [ -n "${YABAI_WINDOW_ID:-}" ]; then
  printf '%s %s\n' "$(date +%s)" "$YABAI_WINDOW_ID" >> "$HIST_FILE"
  tail -n 5000 "$HIST_FILE" > "${HIST_FILE}.tmp" && mv "${HIST_FILE}.tmp" "$HIST_FILE"
fi
