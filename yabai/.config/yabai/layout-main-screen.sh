#!/usr/bin/env bash
set -euo pipefail

SPACE_MAIN="$(yabai -m query --spaces | jq -r '.[] | select(.label=="main") | .index')"
SPACE_STACK="$(yabai -m query --spaces | jq -r '.[] | select(.label=="stack") | .index')"
SPACE_REMOTE="$(yabai -m query --spaces | jq -r '.[] | select(.label=="remote") | .index')"

PRIMARY_DISPLAY="$(
  yabai -m query --displays | jq -r '.[] | select(.index == 1) | .index'
)"

read -r DX DY DW DH < <(
  yabai -m query --displays \
    | jq -r --argjson d "$PRIMARY_DISPLAY" '
        .[] | select(.index == $d) | "\(.frame.x|floor) \(.frame.y|floor) \(.frame.w|floor) \(.frame.h|floor)"
      '
)

FULL_X="$DX"
FULL_Y="$DY"
FULL_W="$DW"
FULL_H="$DH"

HALF_W=$(( DW / 2 ))
HALF_H=$(( DH / 2 ))
RIGHT_X=$(( DX + HALF_W ))
BOTTOM_Y=$(( DY + HALF_H ))

wid_for() {
  local app="$1"
  local space="$2"
  yabai -m query --windows \
    | jq -r --arg app "$app" --argjson space "$space" '
        map(select(.app == $app and .space == $space))
        | sort_by(.id)
        | last.id // empty
      '
}

place() {
  local app="$1"
  local space="$2"
  local x="$3"
  local y="$4"
  local w="$5"
  local h="$6"
  local do_resize="${7:-1}"
  local sublayer="${8:-}"

  local wid
  wid="$(wid_for "$app" "$space")"
  [ -z "$wid" ] && return 0

  yabai -m window "$wid" --move "abs:${x}:${y}"

  if [ "$do_resize" = "1" ]; then
    yabai -m window "$wid" --resize "abs:${w}:${h}"
  fi

  if [ -n "$sublayer" ]; then
    yabai -m window "$wid" --sub-layer "$sublayer"
  fi
}

place "Ghostty" "$SPACE_STACK" "$FULL_X" "$FULL_Y" "$FULL_W" "$FULL_H" 1
place "Zed"     "$SPACE_STACK" "$FULL_X" "$FULL_Y" "$FULL_W" "$FULL_H" 1
place "Vivaldi" "$SPACE_STACK" "$FULL_X" "$FULL_Y" "$FULL_W" "$FULL_H" 1

place "Moonlight"         "$SPACE_REMOTE" "$FULL_X" "$FULL_Y" "$FULL_W" "$FULL_H" 1
place "League of Legends" "$SPACE_REMOTE" "$FULL_X" "$FULL_Y" "$FULL_W" "$FULL_H" 1
