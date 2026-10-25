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
focused() {
  printf 'dispatch hl.dsp.focus({ window = "address:%s" })\ndispatch hl.dsp.window.alter_zorder({ mode = "top", window = "address:%s" })' "$1" "$1"
}

# focus-app: nothing open launches, unless --no-launch.
"$scripts/focus-app" '^helium$' omarchy-launch-browser
expect "launch uwsm-app -- omarchy-launch-browser"
"$scripts/focus-app" --no-launch '^signal$'
expect ""

# From another app the most recent match wins; other classes and excluded titles are skipped.
HYPR_TEST_CLIENTS='[
  {"address":"0xa","class":"foot","title":"zsh","mapped":true,"focusHistoryID":3},
  {"address":"0xb","class":"foot","title":"zsh","mapped":true,"focusHistoryID":1},
  {"address":"0xc","class":"foot","title":".nvim. dotfiles","mapped":true,"focusHistoryID":2},
  {"address":"0xd","class":"helium","title":"Mail","mapped":true,"focusHistoryID":0}
]' "$scripts/focus-app" --exclude-title '\.nvim\.' '^foot$' xdg-terminal-exec
expect "$(focused 0xb)"

# Once inside the app, repeat presses step through every match in a fixed order and wrap, whatever the focus history says.
clients() {
  printf '[{"address":"0xa","class":"foot","title":"a","mapped":true,"stableId":"1","focusHistoryID":%s},
    {"address":"0xb","class":"foot","title":"b","mapped":true,"stableId":"2","focusHistoryID":%s},
    {"address":"0xe","class":"foot","title":"e","mapped":true,"stableId":"3","focusHistoryID":%s}]' "$@"
}
HYPR_TEST_ACTIVE=0xa HYPR_TEST_CLIENTS="$(clients 0 1 2)" "$scripts/focus-app" '^foot$'
expect "$(focused 0xb)"
HYPR_TEST_ACTIVE=0xb HYPR_TEST_CLIENTS="$(clients 1 0 2)" "$scripts/focus-app" '^foot$'
expect "$(focused 0xe)"
HYPR_TEST_ACTIVE=0xe HYPR_TEST_CLIENTS="$(clients 2 1 0)" "$scripts/focus-app" '^foot$'
expect "$(focused 0xa)"
HYPR_TEST_ACTIVE=0xa HYPR_TEST_CLIENTS="$(clients 0 2 1)" "$scripts/focus-app" --reverse '^foot$'
expect "$(focused 0xe)"

# Editors: no match launches Zed; otherwise nvim titles and Zed in stable order, both directions.
editor() { "$scripts/focus-app" --order stable --title '\.nvim\.' "$@" zed zeditor; }
HYPR_TEST_CLIENTS='[]' editor
expect "launch uwsm-app -- zeditor"
export HYPR_TEST_CLIENTS='[
  {"address":"0x1","class":"foot","title":".nvim. api","mapped":true,"stableId":"2","focusHistoryID":1},
  {"address":"0x2","class":"dev.zed.Zed","title":"web","mapped":true,"stableId":"1","focusHistoryID":2},
  {"address":"0x3","class":"foot","title":"zsh","mapped":true,"stableId":"3","focusHistoryID":0}
]'
editor
expect "$(focused 0x2)"
HYPR_TEST_ACTIVE=0x2 editor
expect "$(focused 0x1)"
HYPR_TEST_ACTIVE=0x2 editor --reverse
expect "$(focused 0x1)"
HYPR_TEST_ACTIVE=0x1 editor
expect "$(focused 0x2)"

echo "focus tests passed"
