#!/usr/bin/env bash
# Move new windows to the space of their app sibling, or space 1 if none.
set -euo pipefail

[ -z "${YABAI_WINDOW_ID:-}" ] && exit 0

APP="$(yabai -m query --windows --window "$YABAI_WINDOW_ID" | jq -r '.app // empty')"
[ -z "$APP" ] && exit 0

# Find sibling: oldest window of same app that isn't the new one
SIBLING_SPACE="$(
  yabai -m query --windows \
    | jq -r --arg app "$APP" --argjson wid "$YABAI_WINDOW_ID" '
        map(select(.app == $app and .id != $wid))
        | sort_by(.id)
        | first.space // empty
      '
)"

TARGET="${SIBLING_SPACE:-1}"
yabai -m window "$YABAI_WINDOW_ID" --space "$TARGET" || true
