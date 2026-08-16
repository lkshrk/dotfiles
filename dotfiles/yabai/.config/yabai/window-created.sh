#!/usr/bin/env bash
# First app windows use auto-layout; later windows keep macOS placement.
# App-specific rules run before this fallback.
set -euo pipefail

[ -z "${YABAI_WINDOW_ID:-}" ] && exit 0

WIN="$(yabai -m query --windows --window "$YABAI_WINDOW_ID" 2>/dev/null)"
APP="$(echo "$WIN" | jq -r '.app // empty')"
[ -z "$APP" ] && exit 0
TITLE="$(echo "$WIN" | jq -r '.title // empty')"

if [ "$APP" = "Brave Browser" ] && [ "$TITLE" = "Picture in Picture" ]; then
  exec "$(dirname "$0")/place-pip.sh" "$YABAI_WINDOW_ID"
fi

# Only manage real top-level windows — skip popovers/dropdowns/sheets/dialogs
SUBROLE="$(echo "$WIN" | jq -r '.subrole // empty')"
[ "$SUBROLE" != "AXStandardWindow" ] && exit 0

# Existing apps keep macOS's default position and size
HAS_SIBLING="$(
  yabai -m query --windows \
    | jq -r --arg app "$APP" --argjson wid "$YABAI_WINDOW_ID" '
        any(.[]; .app == $app and .id != $wid)
      '
)"
[ "$HAS_SIBLING" = true ] && exit 0

exec "$(dirname "$0")/apply-layout.sh" "$YABAI_WINDOW_ID"
