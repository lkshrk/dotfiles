#!/usr/bin/env bash
set -euo pipefail

wid="${1:-${YABAI_WINDOW_ID:-}}"
[ -z "$wid" ] && exit 0

win="$(yabai -m query --windows --window "$wid" 2>/dev/null)"
[ "$(echo "$win" | jq -r '.app == "Brave Browser" and .title == "Picture in Picture"')" = true ] || exit 0

yabai -m window "$wid" --space stream || true
yabai -m window "$wid" --resize abs:1264:711 || true
yabai -m window "$wid" --move abs:-1268:-411 || true
yabai -m window "$wid" --sub-layer above || true
