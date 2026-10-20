#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$REPO_DIR/dotfiles/yabai/.config/yabai"
FAKE_BIN="$(mktemp -d)"
trap 'rm -rf "$FAKE_BIN"' EXIT
export PATH="$FAKE_BIN:$PATH"
export CALLS="$FAKE_BIN/calls"
export APP=Obsidian SUBROLE=AXStandardWindow

cat > "$FAKE_BIN/yabai" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '-m query --displays')
    echo '[{"index":1,"frame":{"x":0,"y":0,"w":1920,"h":1080}},{"index":2,"frame":{"x":1920,"y":-200,"w":1200,"h":2000}}]' ;;
  '-m query --spaces')
    echo '[{"index":1,"display":1,"is-native-fullscreen":false},{"index":3,"display":2,"is-native-fullscreen":false}]' ;;
  '-m query --windows --window 22')
    jq -n --arg app "$APP" --arg subrole "$SUBROLE" '{id:22,app:$app,subrole:$subrole}' ;;
  '-m query --windows')
    jq -n --arg app "$APP" '[{id:11,app:$app},{id:22,app:$app}]' ;;
  '-m window '*) echo "$*" >> "$CALLS" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$FAKE_BIN/yabai"

check_placement() {
  local wid="$1"
  grep -qx -- "-m window $wid --space 3" "$CALLS"
  grep -qx -- "-m window $wid --move abs:1920:900" "$CALLS"
  grep -qx -- "-m window $wid --resize abs:1200:900" "$CALLS"
}

bash "$CONFIG_DIR/apply-layout.sh"
check_placement 11
check_placement 22

: > "$CALLS"
YABAI_WINDOW_ID=22 bash "$CONFIG_DIR/window-created.sh"
check_placement 22
[[ "$(wc -l < "$CALLS")" -eq 3 ]]

: > "$CALLS"
SUBROLE=AXDialog YABAI_WINDOW_ID=22 bash "$CONFIG_DIR/window-created.sh"
[[ ! -s "$CALLS" ]]

APP=Zed YABAI_WINDOW_ID=22 bash "$CONFIG_DIR/window-created.sh"
[[ ! -s "$CALLS" ]]

echo 'PASS: all Obsidian windows use portrait bottom 45%; dialogs and other apps retain their behavior'
