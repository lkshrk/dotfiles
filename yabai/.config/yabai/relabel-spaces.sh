#!/usr/bin/env bash
set -euo pipefail

PRIMARY_TARGET=3
SECONDARY_TARGET=2

primary_display="$(
  yabai -m query --displays | jq -r '[.[] | select(.frame.w > .frame.h)] | sort_by(.frame.w) | last | .index'
)"

secondary_display="$(
  yabai -m query --displays | jq -r '[.[] | select(.frame.h > .frame.w)] | sort_by(.frame.h) | last | .index'
)"

if [ -z "${primary_display:-}" ] || [ -z "${secondary_display:-}" ]; then
  exit 1
fi

normal_spaces_for_display() {
  local display_index="$1"
  yabai -m query --spaces | jq -r --argjson d "$display_index" '
    .[]
    | select(.display == $d and ."is-native-fullscreen" == false)
    | .index
  ' | sort -n
}

count_nonempty_lines() {
  awk 'NF { count++ } END { print count+0 }'
}

focus_display_if_needed() {
  local display_index="$1"
  local focused
  focused="$(yabai -m query --displays | jq -r '.[] | select(."has-focus" == true) | .index')"

  if [ "$focused" != "$display_index" ]; then
    yabai -m display --focus "$display_index"
    sleep 0.1
  fi
}

ensure_space_count() {
  local display_index="$1"
  local target="$2"

  local spaces current
  spaces="$(normal_spaces_for_display "$display_index")"
  current="$(printf '%s\n' "$spaces" | count_nonempty_lines)"

  while [ "$current" -lt "$target" ]; do
    focus_display_if_needed "$display_index"
    yabai -m space --create
    sleep 0.2
    spaces="$(normal_spaces_for_display "$display_index")"
    current="$(printf '%s\n' "$spaces" | count_nonempty_lines)"
  done
}

label_spaces() {
  local primary_spaces secondary_spaces

  primary_spaces="$(normal_spaces_for_display "$primary_display")"
  secondary_spaces="$(normal_spaces_for_display "$secondary_display")"

  local primary_arr=()
  while IFS= read -r line; do
    [ -n "$line" ] && primary_arr+=("$line")
  done <<EOF
$primary_spaces
EOF

  local secondary_arr=()
  while IFS= read -r line; do
    [ -n "$line" ] && secondary_arr+=("$line")
  done <<EOF
$secondary_spaces
EOF

  [ "${#primary_arr[@]}" -ge 1 ] && yabai -m space "${primary_arr[0]}" --label main
  [ "${#primary_arr[@]}" -ge 2 ] && yabai -m space "${primary_arr[1]}" --label stack
  [ "${#primary_arr[@]}" -ge 3 ] && yabai -m space "${primary_arr[2]}" --label remote

  [ "${#secondary_arr[@]}" -ge 1 ] && yabai -m space "${secondary_arr[0]}" --label comms
  [ "${#secondary_arr[@]}" -ge 2 ] && yabai -m space "${secondary_arr[1]}" --label stream
}

ensure_space_count "$primary_display" "$PRIMARY_TARGET"
ensure_space_count "$secondary_display" "$SECONDARY_TARGET"
label_spaces
