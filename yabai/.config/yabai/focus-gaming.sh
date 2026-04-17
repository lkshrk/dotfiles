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
  yabai -m window "$WIN_ID" --focus
  sleep 0.1

  FRAME="$(yabai -m query --windows --window "$WIN_ID")"
  X="$(echo "$FRAME" | jq -r '(.frame.x + (.frame.w / 2)) | floor')"
  Y="$(echo "$FRAME" | jq -r '(.frame.y + (.frame.h / 2)) | floor')"

  # move cursor to center first, then click there
  cliclick m:"$X","$Y"
  sleep 0.02
  cliclick c:"$X","$Y"
else
  yabai -m space --focus "$FALLBACK_SPACE"
fi
