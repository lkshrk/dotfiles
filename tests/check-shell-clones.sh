#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
script="$("$repo/scripts/render-home.sh" towerr "$tmp/render")/.config/omarchy/scripts/check-shell-clones"
export CLONES_TEST_ACTIONS="$tmp/actions"
export HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp/run"
mkdir -p "$tmp/bin" "$HOME/.config/omarchy" "$XDG_RUNTIME_DIR/quickshell/by-id/s1"
log="$XDG_RUNTIME_DIR/quickshell/by-id/s1/log.log"

cat > "$tmp/bin/quickshell" <<'EOF'
#!/usr/bin/env bash
echo '[{"id":"s1","config_path":"/usr/share/omarchy/shell/shell.qml","launch_time":1}]'
EOF
cat > "$tmp/bin/omarchy-shell" <<'EOF'
#!/usr/bin/env bash
[ -z "${CLONES_TEST_LOCK_DEAD:-}" ]
EOF
cat > "$tmp/bin/omarchy" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$CLONES_TEST_ACTIONS"
EOF
cat > "$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
echo "notify $5" >> "$CLONES_TEST_ACTIONS"
EOF
printf '#!/bin/sh\n' > "$tmp/bin/sleep"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"

expect() {
  local actual
  actual="$(cat "$CLONES_TEST_ACTIONS" 2>/dev/null || true)"
  [ "$actual" = "$1" ] || { printf 'expected %q\n     got %q\n' "$1" "$actual" >&2; exit 1; }
  : > "$CLONES_TEST_ACTIONS"
}
fell_back() {
  printf 'plugin disable %s\nplugin enable %s\nnotify %s clone failed to load: Switched back to Omarchy'\''s %s. Re-sync %s, then: omarchy plugin enable %s' \
    "$1" "$2" "$3" "$2" "$1" "$1"
}

cat > "$HOME/.config/omarchy/shell.json" <<'EOF'
{
  "bar": {"layout": {"right": [{"id": "omarchy.audio"}, {"id": "lkshrk.tray", "pinned": ["x"]}]}},
  "plugins": [{"id": "lkshrk.lock"}, {"id": "lkshrk.polkit"}]
}
EOF

# A healthy shell leaves every clone alone.
echo ' WARN qml: Plugin widget someone.else failed: boom' > "$log"
"$script"
expect ""

# A bar-widget clone that fails to load falls back to the stock tray.
echo ' WARN qml: Plugin widget lkshrk.tray failed: Type TrayModel unavailable' > "$log"
"$script"
expect "$(fell_back lkshrk.tray omarchy.tray "System tray")"

# Service clones still fall back on their own load error, and a silent lock on IPC.
echo ' WARN qml: service plugin load failed for lkshrk.polkit: syntax error' > "$log"
CLONES_TEST_LOCK_DEAD=1 "$script"
expect "$(fell_back lkshrk.lock omarchy.lock "Lock screen")
$(fell_back lkshrk.polkit omarchy.polkit "Password prompt")"

# A tray failure is ignored when the clone is not on the bar.
jq 'del(.bar)' "$HOME/.config/omarchy/shell.json" > "$tmp/shell.json" && mv "$tmp/shell.json" "$HOME/.config/omarchy/shell.json"
echo ' WARN qml: Plugin widget lkshrk.tray failed: boom' > "$log"
"$script"
expect ""

echo "check-shell-clones: ok"
