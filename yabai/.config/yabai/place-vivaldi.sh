#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"
FIRST_SPACE="${3:-comms}"
SECOND_SPACE="${2:-stack}"

[ -z "$APP_NAME" ] && exit 1
[ -z "${YABAI_WINDOW_ID:-}" ] && exit 0

sleep 0.1

ids="$(
  yabai -m query --windows \
    | jq -r --arg app "$APP_NAME" '
        map(select(.app == $app))
        | sort_by(.id)
        | .[].id
      '
)"

count=0
first_id=""
second_id=""

while IFS= read -r id; do
  [ -z "$id" ] && continue
  count=$((count + 1))
  if [ "$count" -eq 1 ]; then
    first_id="$id"
  elif [ "$count" -eq 2 ]; then
    second_id="$id"
  fi
done <<EOF
$ids
EOF

[ -n "$first_id" ] && yabai -m window "$first_id" --space "$FIRST_SPACE" || true
[ -n "$second_id" ] && yabai -m window "$second_id" --space "$SECOND_SPACE" || true
