#!/usr/bin/env bash
set -uo pipefail

problems=0
problem() {
  echo "yabai health: $*" >&2
  problems=$((problems + 1))
}

yabai_path="$(command -v yabai || true)"
[ -n "$yabai_path" ] || { problem "yabai not in PATH"; exit 1; }

if ! yabai -m query --spaces >/dev/null 2>&1; then
  problem "daemon not responding; check Accessibility grant, then yabai --restart-service"
  exit 1
fi

# sudo -n -l does not verify the sha256 digest, so only a real run tells a stale hash from a failing load
if ! sa_error="$(sudo -n "$yabai_path" --load-sa 2>&1)"; then
  case "$sa_error" in
    *"password is required"*) problem "sudoers hash stale; run ~/.config/yabai/update_sudoers.sh" ;;
    *) problem "scripting addition failed to load on macOS $(sw_vers -productVersion)" ;;
  esac
fi

pgrep -xq skhd || problem "skhd not running"

[ "$problems" -eq 0 ] && echo "yabai health: ok"
exit $((problems > 0))
