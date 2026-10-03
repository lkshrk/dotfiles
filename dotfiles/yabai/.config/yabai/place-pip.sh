#!/usr/bin/env bash
set -euo pipefail

wid="${1:-${YABAI_WINDOW_ID:-}}"
[ -z "$wid" ] && exit 0

win="$(yabai -m query --windows --window "$wid" 2>/dev/null)"
[ "$(echo "$win" | jq -r '.app == "Brave Browser" and .title == "Picture in Picture"')" = true ] || exit 0

portrait="$(yabai -m query --displays | jq -c '[.[] | select(.frame.h > .frame.w)] | sort_by(.frame.h) | last // empty')"
[ -n "$portrait" ] || exit 0
read -r display dx dy dw < <(jq -r '"\(.index) \(.frame.x|floor) \(.frame.y|floor) \(.frame.w|floor)"' <<<"$portrait")
space="$(yabai -m query --spaces --display "$display" | jq -r '[.[] | select(."is-native-fullscreen" == false) | .index] | min // empty')"
[ -n "$space" ] || exit 0

# Place once per window so manual moves stick across later title-change signals.
state="${YABAI_PIP_STATE:-${TMPDIR:-/tmp}/yabai-pip-placed}"
[ "$(cat "$state" 2>/dev/null)" = "$wid" ] && exit 0
echo "$wid" > "$state"

w=1264 h=711 gap=4

yabai -m window "$wid" --space "$space" || true
yabai -m window "$wid" --resize "abs:$w:$h" || true
yabai -m window "$wid" --move "abs:$((dx + dw - w - gap)):$((dy + gap))" || true
yabai -m window "$wid" --sub-layer above || true
