#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export YABAI_TEST_ACTIONS="$tmp/actions"
export YABAI_PIP_STATE="$tmp/pip-placed"

cat > "$tmp/yabai" <<'EOF'
#!/usr/bin/env bash
if [ "$*" = "-m query --windows --window 42" ]; then
  echo '{"id":42,"app":"Brave Browser","title":"Picture in Picture"}'
elif [ "$*" = "-m query --displays" ]; then
  if [ -n "${YABAI_TEST_NO_PORTRAIT:-}" ]; then
    echo '[{"index":1,"frame":{"x":0,"y":0,"w":2560,"h":1440}}]'
  else
    echo '[{"index":1,"frame":{"x":0,"y":0,"w":2560,"h":1440}},{"index":2,"frame":{"x":-1440,"y":-400,"w":1440,"h":2560}}]'
  fi
elif [ "$*" = "-m query --spaces --display 2" ]; then
  echo '[{"index":5,"is-native-fullscreen":false},{"index":4,"is-native-fullscreen":false}]'
else
  echo "$*" >> "$YABAI_TEST_ACTIONS"
fi
EOF
chmod +x "$tmp/yabai"

PATH="$tmp:$PATH" YABAI_TEST_NO_PORTRAIT=1 YABAI_WINDOW_ID=42 "$(dirname "$0")/../place-pip.sh"
[ ! -e "$YABAI_TEST_ACTIONS" ] && [ ! -e "$YABAI_PIP_STATE" ] || {
  echo 'expected no placement and no state without a portrait display' >&2
  exit 1
}

PATH="$tmp:$PATH" YABAI_WINDOW_ID=42 "$(dirname "$0")/../window-created.sh"

expected="$(cat <<'EOF'
-m window 42 --space 4
-m window 42 --resize abs:1264:711
-m window 42 --move abs:-1268:-396
-m window 42 --sub-layer above
EOF
)"
actual="$(cat "$YABAI_TEST_ACTIONS" 2>/dev/null || true)"
[ "$actual" = "$expected" ] || {
  printf 'expected:\n%s\ngot:\n%s\n' "$expected" "$actual" >&2
  exit 1
}

rm -f "$YABAI_TEST_ACTIONS"
PATH="$tmp:$PATH" YABAI_WINDOW_ID=42 "$(dirname "$0")/../place-pip.sh"
[ ! -s "$YABAI_TEST_ACTIONS" ] || {
  printf 'expected no re-placement, got:\n%s\n' "$(cat "$YABAI_TEST_ACTIONS")" >&2
  exit 1
}
