#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  toggle) js="(v=>v.paused?v.play():v.pause())(document.querySelector('video'))" ;;
  next)   js="document.querySelector('.ytp-next-button').click()" ;;
  restart) js="document.querySelector('video').currentTime=0" ;;
  *) echo "usage: $0 toggle|next|restart" >&2; exit 1 ;;
esac

pgrep -xq "Brave Browser" || exit 0

osascript - "$js" >/dev/null <<'EOF'
on run argv
  tell application "Brave Browser"
    set target to missing value
    repeat with w in windows
      repeat with t in tabs of w
        if URL of t contains "youtube.com/watch" then
          if target is missing value then set target to t
          if (execute t javascript "String(!document.querySelector('video').paused)") is "true" then
            set target to t
            exit repeat
          end if
        end if
      end repeat
    end repeat
    if target is not missing value then execute target javascript (item 1 of argv)
  end tell
end run
EOF
