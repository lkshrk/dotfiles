#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export YABAI_TEST_ACTIONS="$tmp/actions"

cat > "$tmp/yabai" <<'EOF'
#!/usr/bin/env bash
if [ "$*" = "-m query --displays" ]; then
  echo '[{"index":1,"frame":{"x":0,"y":0,"w":2560,"h":1440}},{"index":2,"frame":{"x":-1440,"y":-467,"w":1440,"h":2560}}]'
elif [ "$*" = "-m query --spaces" ]; then
  echo '[{"index":1,"display":1,"is-native-fullscreen":false},{"index":2,"display":1,"is-native-fullscreen":false},{"index":3,"display":1,"is-native-fullscreen":false},{"index":4,"display":2,"is-native-fullscreen":false},{"index":5,"display":2,"is-native-fullscreen":false}]'
elif [[ "$*" == "-m query --windows --window "* ]]; then
  if [ "$YABAI_WINDOW_ID" = 44 ]; then
    echo '{"id":44,"app":"Telegram","subrole":"AXStandardWindow"}'
  elif [ "$YABAI_WINDOW_ID" = 45 ]; then
    echo '{"id":45,"app":"League of Legends","subrole":"AXStandardWindow"}'
  else
    echo "{\"id\":$YABAI_WINDOW_ID,\"app\":\"Finder\",\"subrole\":\"AXStandardWindow\"}"
  fi
elif [ "$*" = "-m query --windows" ]; then
  case "$YABAI_WINDOW_ID" in
    42) echo '[{"id":42,"app":"Finder","frame":{"x":1800,"y":300,"w":1000,"h":600}}]' ;;
    43) echo '[{"id":42,"app":"Finder"},{"id":43,"app":"Finder"}]' ;;
    44) echo '[{"id":44,"app":"Telegram","title":"Telegram"}]' ;;
    45) echo '[{"id":45,"app":"League of Legends"}]' ;;
  esac
else
  echo "$*" >> "$YABAI_TEST_ACTIONS"
fi
EOF
chmod +x "$tmp/yabai"

PATH="$tmp:$PATH" YABAI_WINDOW_ID=42 "$(dirname "$0")/../window-created.sh"

expected=$'-m window 42 --space 1\n-m window 42 --move abs:780:420'
actual="$(cat "$YABAI_TEST_ACTIONS" 2>/dev/null || true)"
[ "$actual" = "$expected" ] || {
  printf 'expected %q, got %q\n' "$expected" "$actual" >&2
  exit 1
}

rm -f "$YABAI_TEST_ACTIONS"
PATH="$tmp:$PATH" YABAI_WINDOW_ID=43 "$(dirname "$0")/../window-created.sh"
[ ! -e "$YABAI_TEST_ACTIONS" ] || {
  printf 'expected no action, got %q\n' "$(cat "$YABAI_TEST_ACTIONS")" >&2
  exit 1
}

PATH="$tmp:$PATH" YABAI_WINDOW_ID=44 "$(dirname "$0")/../window-created.sh"
expected="$(cat <<'EOF'
-m window 44 --space 4
-m window 44 --move abs:-1440:1240
-m window 44 --resize abs:1440:853
EOF
)"
actual="$(cat "$YABAI_TEST_ACTIONS" 2>/dev/null || true)"
[ "$actual" = "$expected" ] || {
  printf 'expected:\n%s\ngot:\n%s\n' "$expected" "$actual" >&2
  exit 1
}

rm -f "$YABAI_TEST_ACTIONS"
PATH="$tmp:$PATH" YABAI_WINDOW_ID=45 "$(dirname "$0")/../window-created.sh"
expected="$(cat <<'EOF'
-m window 45 --space 3
-m window 45 --move abs:0:0
-m window 45 --resize abs:2560:1440
EOF
)"
actual="$(cat "$YABAI_TEST_ACTIONS" 2>/dev/null || true)"
[ "$actual" = "$expected" ] || {
  printf 'expected:\n%s\ngot:\n%s\n' "$expected" "$actual" >&2
  exit 1
}
