#!/usr/bin/env bash
set -euo pipefail

SPACE_COMMS="$(yabai -m query --spaces | jq -r '.[] | select(.label=="comms") | .index')"
SPACE_STREAM="$(yabai -m query --spaces | jq -r '.[] | select(.label=="stream") | .index')"

SECONDARY_DISPLAY="$(
  yabai -m query --displays | jq -r '[.[] | select(.frame.h > .frame.w)] | sort_by(.frame.h) | last | .index'
)"

read -r DX DY DW DH < <(
  yabai -m query --displays \
    | jq -r --argjson d "$SECONDARY_DISPLAY" '
        .[] | select(.index == $d) | "\(.frame.x|floor) \(.frame.y|floor) \(.frame.w|floor) \(.frame.h|floor)"
      '
)

HALF_W=$(( DW / 2 ))
HALF_H=$(( DH / 2 ))
QUARTER_H=$(( DH / 4 ))
BOTTOM_HALF_Y=$(( DY + HALF_H ))
BOTTOM_QUARTER_Y=$(( DY + DH - QUARTER_H ))

LEFT_INSET=50
LEFT_X=$DX
LEFT_INSET_X=$(( DX + LEFT_INSET ))
RIGHT_X=$(( DX + HALF_W ))

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

place_centered_scaled() {
  local app="$1"
  local target_space="$2"
  local scale="$3"

  local wid
  wid="$(
    yabai -m query --windows \
      | jq -r --arg app "$app" '
          map(select(.app == $app))
          | sort_by(.id)
          | last.id // empty
        '
  )"
  [ -z "$wid" ] && return 0

  yabai -m window "$wid" --space "$target_space"

  local w=$(( DW * scale / 100 ))
  local h=$(( DH * scale / 100 ))
  local x=$(( DX + (DW - w) / 2 ))
  local y=$(( DY + (DH - h) / 2 ))

  yabai -m window "$wid" --move "abs:${x}:${y}"
  yabai -m window "$wid" --resize "abs:${w}:${h}"
}

place_centered_bottom_in_region() {
  local app="$1"
  local space="$2"
  local region_x="$3"
  local region_y="$4"
  local region_w="$5"
  local region_h="$6"

  local wid
  wid="$(wid_for "$app" "$space")"
  [ -z "$wid" ] && return 0

  read -r ww wh < <(
    yabai -m query --windows --window "$wid" | jq -r '.frame | "\(.w|floor) \(.h|floor)"'
  )

  local x=$(( region_x + (region_w - ww) / 2 ))
  local y=$(( region_y + region_h - wh ))

  yabai -m window "$wid" --move "abs:${x}:${y}"
}

place "Discord"       "$SPACE_COMMS" "$LEFT_X"       "$DY"               "$HALF_W"                     "$DH"              1
place "ChatGPT"       "$SPACE_COMMS" "$LEFT_INSET_X" "$DY"               "$(( HALF_W - LEFT_INSET ))" "$DH"              1
place "Vivaldi"       "$SPACE_COMMS" "$LEFT_INSET_X" "$DY"               "$(( HALF_W - LEFT_INSET ))" "$DH"              1
place "Signal"        "$SPACE_COMMS" "$LEFT_X"       "$BOTTOM_HALF_Y"    "$HALF_W"                     "$HALF_H"          1
place "Messages"      "$SPACE_COMMS" "$LEFT_X"       "$BOTTOM_HALF_Y"    "$HALF_W"                     "$HALF_H"          1
place_centered_bottom_in_region "Chatterino" "$SPACE_COMMS" "$RIGHT_X" "$BOTTOM_HALF_Y" "$HALF_W" "$HALF_H"
place "OBS"           "$SPACE_COMMS" "$RIGHT_X"      "$BOTTOM_QUARTER_Y" "$HALF_W"                     "$(( DH * 3 / 4 ))" 1
place "Brave Browser" "$SPACE_COMMS" "$RIGHT_X"      "$DY"               "$HALF_W"                     "$(( DH * 3 / 4 ))" 1 "above"

place_centered_scaled "Obsidian" "$SPACE_STREAM" 75
place "Stream Deck"       "$SPACE_STREAM" "$LEFT_X"  "$DY" "$HALF_W" "$DH" 1
place "Elgato Wave Link"  "$SPACE_STREAM" "$RIGHT_X" "$DY" "$HALF_W" "$DH" 1
