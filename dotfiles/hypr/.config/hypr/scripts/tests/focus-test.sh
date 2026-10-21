#!/usr/bin/env bash
set -euo pipefail

scripts="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HYPR_TEST_ACTIONS="$tmp/actions"

cat > "$tmp/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "clients -j") echo "${HYPR_TEST_CLIENTS:-[]}" ;;
  "activewindow -j") printf '{"address":"%s"}\n' "${HYPR_TEST_ACTIVE:-}" ;;
  "monitors -j") echo "${HYPR_TEST_MONITORS:-[]}" ;;
  *) echo "$*" >> "$HYPR_TEST_ACTIONS" ;;
esac
EOF
cat > "$tmp/setsid" <<'EOF'
#!/usr/bin/env bash
echo "launch $*" >> "$HYPR_TEST_ACTIONS"
EOF
chmod +x "$tmp/hyprctl" "$tmp/setsid"
export PATH="$tmp:$PATH"

expect() {
  local actual
  actual="$(cat "$HYPR_TEST_ACTIONS" 2>/dev/null || true)"
  [ "$actual" = "$1" ] || { printf 'expected %q\n     got %q\n' "$1" "$actual" >&2; exit 1; }
  : > "$HYPR_TEST_ACTIONS"
}
focused() { echo "dispatch hl.dsp.focus({ window = \"address:$1\" })"; }

# focus-app: nothing open launches, unless --no-launch.
"$scripts/focus-app" '^helium$' omarchy-launch-browser
expect "launch uwsm-app -- omarchy-launch-browser"
"$scripts/focus-app" --no-launch '^signal$'
expect ""

# Most recently used first, then cycle; other classes and excluded titles are skipped.
export HYPR_TEST_CLIENTS='[
  {"address":"0xa","class":"foot","title":"zsh","mapped":true,"focusHistoryID":3},
  {"address":"0xb","class":"foot","title":"zsh","mapped":true,"focusHistoryID":1},
  {"address":"0xc","class":"foot","title":".nvim. dotfiles","mapped":true,"focusHistoryID":2},
  {"address":"0xd","class":"helium","title":"Mail","mapped":true,"focusHistoryID":0}
]'
HYPR_TEST_ACTIVE=0xd "$scripts/focus-app" --exclude-title '\.nvim\.' '^foot$' xdg-terminal-exec
expect "$(focused 0xb)"
HYPR_TEST_ACTIVE=0xb "$scripts/focus-app" --exclude-title '\.nvim\.' '^foot$' xdg-terminal-exec
expect "$(focused 0xa)"
HYPR_TEST_ACTIVE=0xa "$scripts/focus-app" --exclude-title '\.nvim\.' '^foot$' xdg-terminal-exec
expect "$(focused 0xb)"

# focus-editor: nvim titles and Zed in stable order, both directions.
export HYPR_TEST_CLIENTS='[
  {"address":"0x1","class":"foot","title":".nvim. api","mapped":true,"stableId":"2"},
  {"address":"0x2","class":"dev.zed.Zed","title":"web","mapped":true,"stableId":"1"},
  {"address":"0x3","class":"foot","title":"zsh","mapped":true,"stableId":"3"}
]'
"$scripts/focus-editor"
expect "$(focused 0x2)"
HYPR_TEST_ACTIVE=0x2 "$scripts/focus-editor"
expect "$(focused 0x1)"
HYPR_TEST_ACTIVE=0x2 "$scripts/focus-editor" --reverse
expect "$(focused 0x1)"

# focus-gaming: a game window wins, otherwise the gaming workspace.
HYPR_TEST_CLIENTS='[{"address":"0x9","class":"steam_app_570","title":"Dota 2","mapped":true,"focusHistoryID":4,"contentType":"none"}]' \
  "$scripts/focus-gaming"
expect "$(focused 0x9)"
HYPR_TEST_CLIENTS='[]' "$scripts/focus-gaming"
expect 'dispatch hl.dsp.focus({ workspace = "9" })'

# snap-half: portrait monitor (transform 1) with a 30px bar on top.
HYPR_TEST_MONITORS='[{"focused":true,"x":2560,"y":0,"width":2560,"height":1440,"scale":1,"transform":1,"reserved":[0,30,0,0]}]' \
  "$scripts/snap-half" right
expect $'dispatch hl.dsp.window.float({ action = "set" })\ndispatch hl.dsp.window.resize({ x = 720, y = 2530 })\ndispatch hl.dsp.window.move({ x = 3280, y = 30 })'
HYPR_TEST_MONITORS='[{"focused":true,"x":2560,"y":0,"width":2560,"height":1440,"scale":1,"transform":1,"reserved":[0,30,0,0]}]' \
  "$scripts/snap-half" bottom
expect $'dispatch hl.dsp.window.float({ action = "set" })\ndispatch hl.dsp.window.resize({ x = 1440, y = 1265 })\ndispatch hl.dsp.window.move({ x = 2560, y = 1295 })'

echo "focus tests passed"
