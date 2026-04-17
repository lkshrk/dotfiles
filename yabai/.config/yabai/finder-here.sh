#!/usr/bin/env bash
set -euo pipefail

current_space="$(yabai -m query --spaces --space | jq '.index')"

# 1) If Finder already has a window on the current space, focus it.
existing_id="$(
  yabai -m query --windows \
    | jq -r --argjson space "$current_space" '
        map(select(.app == "Finder" and .space == $space))
        | .[0].id // empty
      '
)"

if [ -n "$existing_id" ]; then
  yabai -m window --focus "$existing_id"
  exit 0
fi

# 2) Otherwise create a new Finder window.
osascript <<'APPLESCRIPT'
tell application "Finder"
  activate
  make new Finder window
end tell
APPLESCRIPT

# 3) Wait briefly for the window to exist, then move the newest Finder window
#    to the current space and focus it.
for _ in {1..20}; do
  new_id="$(
    yabai -m query --windows \
      | jq -r '
          map(select(.app == "Finder"))
          | sort_by(.id)
          | last.id // empty
        '
  )"

  if [ -n "$new_id" ]; then
    yabai -m window "$new_id" --space "$current_space"
    yabai -m window --focus "$new_id"
    exit 0
  fi

  sleep 0.05
done

exit 1
