#!/usr/bin/env bash
set -euo pipefail

TITLE="towerr"
ALT_APP="moonlight"
FALLBACK_SPACE="3"

WIN_ID=$(
  yabai -m query --windows \
    | jq -r --arg title "$TITLE" --arg app "$ALT_APP" '
        .[]
        | select(
            (.title // "" | ascii_downcase) == ($title | ascii_downcase)
            or (.app // "" | ascii_downcase) == ($app | ascii_downcase)
          )
        | .id
      ' \
    | head -n1
)

if [ -n "$WIN_ID" ]; then
  # Exclusive fullscreen windows can be listed but cannot be focused by yabai.
  if ! yabai -m window "$WIN_ID" --focus; then
    WINDOW="$(yabai -m query --windows | jq --argjson id "$WIN_ID" '.[] | select(.id == $id)')"
    SPACE="$(jq -r '.space' <<< "$WINDOW")"
    CURRENT_SPACE="$(yabai -m query --spaces --space | jq -r '.index')"
    if [ "$CURRENT_SPACE" != "$SPACE" ]; then
      yabai -m space --focus "$SPACE"
    fi
    open -a "$(jq -r '.app' <<< "$WINDOW")"
  fi
else
  yabai -m space --focus "$FALLBACK_SPACE"
fi
