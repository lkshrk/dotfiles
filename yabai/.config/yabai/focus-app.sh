#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"
EXCLUDE_TITLE="${2:-}"

if [ -z "$APP_NAME" ]; then
  echo "usage: $0 <App Name> [exclude-title-regex]" >&2
  exit 1
fi

PREFERRED_DISPLAY_INDEX="$(
  yabai -m query --displays \
    | jq -r '[.[] | select(.frame.w > .frame.h)] | sort_by(.frame.w) | last | .index'
)"

STACK_SPACE_INDEX="$(
  yabai -m query --spaces \
    | jq -r '.[] | select(.label == "stack") | .index'
)"

if [ -z "$PREFERRED_DISPLAY_INDEX" ]; then
  echo "preferred display not found" >&2
  exit 1
fi

FOCUS_HISTORY="$(
  if [ -f "${TMPDIR:-/tmp}/yabai_window_focus_history" ]; then
    tac "${TMPDIR:-/tmp}/yabai_window_focus_history" 2>/dev/null \
      | awk 'NF==2 && !seen[$2]++ {print $2, $1}' \
      | jq -R -s '
          split("\n")
          | map(select(length > 0))
          | map(split(" ") | { key: .[0], value: (.[1] | tonumber) })
          | from_entries
        '
  else
    echo '{}'
  fi
)"

WINDOW_IDS="$(
  yabai -m query --windows \
    | jq -r \
      --arg app "$APP_NAME" \
      --arg exclude "$EXCLUDE_TITLE" \
      --argjson hist "$FOCUS_HISTORY" \
      --argjson preferred "$PREFERRED_DISPLAY_INDEX" \
      --argjson stack "${STACK_SPACE_INDEX:-0}" '
        map(select(.app == $app and ($exclude == "" or (.title | test($exclude) | not))))
        | sort_by(
            -($hist[(.id | tostring)] // 0),
            (if .display == $preferred then 0 else 1 end),
            (if .space == $stack then 0 else 1 end),
            .space,
            .id
          )
        | .[].id
      '
)"

if [ -z "$WINDOW_IDS" ]; then
  open -a "$APP_NAME"
  exit 0
fi

CURRENT_WINDOW_ID="$(
  yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty'
)"

NEXT_WINDOW_ID="$(
  printf '%s\n' "$WINDOW_IDS" \
    | jq -R -s --arg current "$CURRENT_WINDOW_ID" '
        split("\n") | map(select(length > 0)) | map(tonumber) as $ids
        | if ($ids | length) == 0 then
            empty
          elif ($current | length) == 0 then
            $ids[0]
          else
            ($current | tonumber) as $cur
            | ($ids | index($cur)) as $idx
            | if $idx == null then
                $ids[0]
              else
                $ids[($idx + 1) % ($ids | length)]
              end
          end
      '
)"

if [ -n "$NEXT_WINDOW_ID" ]; then
  yabai -m window --focus "$NEXT_WINDOW_ID"
fi
