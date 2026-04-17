#!/usr/bin/env bash
set -euo pipefail

wid="$(yabai -m query --windows --window | jq -r '.id')"
current="$(yabai -m query --windows --window | jq -r '."sub-layer" // "normal"')"

if [ "$current" = "above" ]; then
  yabai -m window "$wid" --sub-layer normal
else
  yabai -m window "$wid" --sub-layer above
fi
