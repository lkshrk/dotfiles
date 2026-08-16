#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export YABAI_TEST_ACTIONS="$tmp/actions"

cat > "$tmp/yabai" <<'EOF'
#!/usr/bin/env bash
if [ "$*" = "-m query --windows --window 42" ]; then
  echo '{"id":42,"app":"Brave Browser","title":"Picture in Picture"}'
else
  echo "$*" >> "$YABAI_TEST_ACTIONS"
fi
EOF
chmod +x "$tmp/yabai"

PATH="$tmp:$PATH" YABAI_WINDOW_ID=42 "$(dirname "$0")/../window-created.sh"

expected="$(cat <<'EOF'
-m window 42 --space stream
-m window 42 --resize abs:1264:711
-m window 42 --move abs:-1268:-411
-m window 42 --sub-layer above
EOF
)"
actual="$(cat "$YABAI_TEST_ACTIONS" 2>/dev/null || true)"
[ "$actual" = "$expected" ] || {
  printf 'expected:\n%s\ngot:\n%s\n' "$expected" "$actual" >&2
  exit 1
}
