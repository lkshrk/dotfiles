#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export YABAI_TEST_ACTIONS="$tmp/actions"

cat > "$tmp/yabai" <<'EOF'
#!/usr/bin/env bash
if [ "$*" = "-m query --displays" ]; then
  echo '[{"index":1,"frame":{"w":2560,"h":1440}}]'
elif [ "$*" = "-m query --windows" ]; then
  echo '[]'
fi
EOF
cat > "$tmp/open" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$YABAI_TEST_ACTIONS"
EOF
chmod +x "$tmp/yabai" "$tmp/open"

PATH="$tmp:$PATH" FOCUS_APP_NO_OPEN=1 "$(dirname "$0")/../focus-app.sh" Signal
[ ! -e "$YABAI_TEST_ACTIONS" ] || {
  printf 'expected no app launch, got %q\n' "$(cat "$YABAI_TEST_ACTIONS")" >&2
  exit 1
}
