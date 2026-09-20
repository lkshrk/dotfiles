#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export YABAI_TEST_ACTIONS="$tmp/actions"
export TMPDIR="$tmp/"

cat > "$tmp/yabai" <<'EOF'
#!/usr/bin/env bash
if [ "$*" = "-m query --displays" ]; then
  echo '[{"index":1,"frame":{"w":2560,"h":1440}}]'
elif [ "$*" = "-m query --windows" ]; then
  echo "${YABAI_TEST_WINDOWS:-[]}"
elif [ "$*" = "-m query --windows --window" ]; then
  [ -n "${YABAI_TEST_CURRENT:-}" ] || exit 1
  printf '{"id":%s}\n' "$YABAI_TEST_CURRENT"
elif [ "$*" = "-m query --spaces --space" ]; then
  printf '{"index":%s}\n' "${YABAI_TEST_SPACE:-2}"
elif [ "$*" = "-m window 42 --focus" ] && [ "${YABAI_TEST_FOCUS_FAIL:-0}" = 1 ]; then
  exit 1
else
  echo "$*" >> "$YABAI_TEST_ACTIONS"
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

export PATH="$tmp:$PATH"
export YABAI_TEST_WINDOWS='[{"id":41,"app":"Helium","display":1,"space":2},{"id":42,"app":"Helium","display":1,"space":2}]'
# Fullscreen apps may have no queryable focused window; still focus the target.
"$(dirname "$0")/../focus-app.sh" Helium
[ "$(cat "$YABAI_TEST_ACTIONS")" = '-m window --focus 41' ]
: > "$YABAI_TEST_ACTIONS"
YABAI_TEST_CURRENT=41 "$(dirname "$0")/../focus-app.sh" Helium
[ "$(cat "$YABAI_TEST_ACTIONS")" = '-m window --focus 42' ]

export YABAI_TEST_WINDOWS='[{"id":42,"app":"Moonlight","title":"towerr","space":4}]'
: > "$YABAI_TEST_ACTIONS"
"$(dirname "$0")/../focus-gaming.sh"
[ "$(cat "$YABAI_TEST_ACTIONS")" = '-m window 42 --focus' ]
: > "$YABAI_TEST_ACTIONS"
YABAI_TEST_FOCUS_FAIL=1 "$(dirname "$0")/../focus-gaming.sh"
[ "$(cat "$YABAI_TEST_ACTIONS")" = $'-m space --focus 4\n-a Moonlight' ]
: > "$YABAI_TEST_ACTIONS"
YABAI_TEST_FOCUS_FAIL=1 YABAI_TEST_SPACE=4 "$(dirname "$0")/../focus-gaming.sh"
[ "$(cat "$YABAI_TEST_ACTIONS")" = '-a Moonlight' ]
: > "$YABAI_TEST_ACTIONS"
YABAI_TEST_WINDOWS='[]' "$(dirname "$0")/../focus-gaming.sh"
[ "$(cat "$YABAI_TEST_ACTIONS")" = '-m space --focus 3' ]
echo 'Focus regression checks passed'
