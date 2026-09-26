#!/usr/bin/env bash
set -euo pipefail

wid="${1:-${YABAI_WINDOW_ID:-}}"
[ -z "$wid" ] && exit 0

win="$(yabai -m query --windows --window "$wid" 2>/dev/null)"
[ "$(echo "$win" | jq -r '.app == "Brave Browser" and .title == "Picture in Picture"')" = true ] || exit 0

# Place once per window so manual moves stick across later title-change signals.
state="${YABAI_PIP_STATE:-${TMPDIR:-/tmp}/yabai-pip-placed}"
[ "$(cat "$state" 2>/dev/null)" = "$wid" ] && exit 0
echo "$wid" > "$state"

w=1264 h=711 gap=4
display="$(yabai -m query --spaces --space stream | jq -r '.display')"
read -r dx dy dw < <(yabai -m query --displays --display "$display" | jq -r '.frame | "\(.x|floor) \(.y|floor) \(.w|floor)"')

yabai -m window "$wid" --space stream || true
yabai -m window "$wid" --resize "abs:$w:$h" || true
yabai -m window "$wid" --move "abs:$((dx + dw - w - gap)):$((dy + gap))" || true
yabai -m window "$wid" --sub-layer above || true
