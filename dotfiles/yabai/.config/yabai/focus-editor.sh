#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

REVERSE=false
[[ "${1:-}" == "--reverse" ]] && REVERSE=true

# Windows with .nvim. in title (nvim inside terminal emulators)
NVIM_IDS="$(yabai -m query --windows | jq -r 'map(select(.title | test("\\.nvim\\."; ""))) | .[].id')"

# Zed windows not already captured by the nvim title match
ZED_IDS="$(yabai -m query --windows | jq -r 'map(select(.app == "Zed" and (.title | test("\\.nvim\\."; "") | not))) | .[].id')"

ALL_IDS="$(printf '%s\n' $NVIM_IDS $ZED_IDS | awk 'NF && !seen[$0]++')"

if [ -z "$ALL_IDS" ]; then
  open -na "Ghostty" --args -e nvim
  exit 0
fi

CURRENT_ID="$(yabai -m query --windows --window 2>/dev/null | jq -r '.id // empty')"

NEXT_ID="$(
  printf '%s\n' "$ALL_IDS" \
    | jq -R -s --arg current "$CURRENT_ID" --arg rev "$REVERSE" '
        split("\n") | map(select(length > 0)) | map(tonumber) as $ids
        | if ($ids | length) == 0 then empty
          elif ($current | length) == 0 then $ids[0]
          else
            ($current | tonumber) as $cur
            | ($ids | index($cur)) as $idx
            | if $idx == null then $ids[0]
              elif $rev == "true" then $ids[($idx - 1 + ($ids | length)) % ($ids | length)]
              else $ids[($idx + 1) % ($ids | length)]
              end
          end
      '
)"

[ -n "$NEXT_ID" ] && yabai -m window --focus "$NEXT_ID"
