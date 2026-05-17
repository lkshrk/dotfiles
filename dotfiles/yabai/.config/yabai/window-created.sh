#!/usr/bin/env bash
# Move new windows of managed apps to their sibling's space.
# Unmanaged apps get default macOS placement (no intervention).
set -euo pipefail

[ -z "${YABAI_WINDOW_ID:-}" ] && exit 0

APP="$(yabai -m query --windows --window "$YABAI_WINDOW_ID" | jq -r '.app // empty')"
[ -z "$APP" ] && exit 0

# Only manage these apps — everything else keeps default macOS behavior
MANAGED_APPS=(
  "Ghostty"
  "Zed"
  "Moonlight"
  "League of Legends"
  "Discord"
  "Claude"
  "Signal"
  "Messages"
  "Chatterino"
  "OBS"
  "Brave Browser"
  "Obsidian"
  "Stream Deck"
  "Elgato Wave Link"
)

managed=false
for m in "${MANAGED_APPS[@]}"; do
  if [[ "$APP" == "$m" ]]; then
    managed=true
    break
  fi
done
$managed || exit 0

# Find sibling: oldest window of same app that isn't the new one
SIBLING_SPACE="$(
  yabai -m query --windows \
    | jq -r --arg app "$APP" --argjson wid "$YABAI_WINDOW_ID" '
        map(select(.app == $app and .id != $wid))
        | sort_by(.id)
        | first.space // empty
      '
)"

# Move to sibling's space, or stay put (default placement) if no sibling
[ -z "$SIBLING_SPACE" ] && exit 0
yabai -m window "$YABAI_WINDOW_ID" --space "$SIBLING_SPACE" || true

# Match sibling's position and size so window doesn't land at random cascade spot
SIBLING_FRAME="$(
  yabai -m query --windows \
    | jq -r --arg app "$APP" --argjson wid "$YABAI_WINDOW_ID" '
        map(select(.app == $app and .id != $wid))
        | sort_by(.id)
        | first.frame // empty
        | "\(.x|floor) \(.y|floor) \(.w|floor) \(.h|floor)"
      '
)"

if [ -n "$SIBLING_FRAME" ]; then
  read -r sx sy sw sh <<< "$SIBLING_FRAME"
  yabai -m window "$YABAI_WINDOW_ID" --move "abs:${sx}:${sy}" 2>/dev/null || true
  yabai -m window "$YABAI_WINDOW_ID" --resize "abs:${sw}:${sh}" 2>/dev/null || true
fi
