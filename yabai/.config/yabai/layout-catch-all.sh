#!/usr/bin/env bash
set -euo pipefail

SPACE_MAIN="$(yabai -m query --spaces | jq -r '.[] | select(.label=="main") | .index')"

yabai -m query --windows \
  | jq -r '
      .[]
      | select(
          .app != "Ghostty" and
          .app != "Zed" and
          .app != "Moonlight" and
          .app != "League of Legends" and
          .app != "Discord" and
          .app != "ChatGPT" and
          .app != "Signal" and
          .app != "Messages" and
          .app != "Chatterino" and
          .app != "OBS" and
          .app != "Brave Browser" and
          .app != "Obsidian" and
          .app != "Stream Deck" and
          .app != "Elgato Wave Link" and
          .app != "Vivaldi"
      )
      | .id
    ' \
  | while read -r wid; do
      [ -n "$wid" ] || continue
      yabai -m window "$wid" --space "$SPACE_MAIN"
    done
