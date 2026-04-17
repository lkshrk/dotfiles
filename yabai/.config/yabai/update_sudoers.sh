#!/usr/bin/env bash
# Configure passwordless `yabai --load-sa`. Must be re-run after every yabai
# upgrade because the binary hash changes and the sudoers entry pins the hash.
#
# Usage:
#   ./update_sudoers.sh           # interactive
#   ./update_sudoers.sh --check   # exit 0 if up-to-date, 1 if drift, 2 on error
#   ./update_sudoers.sh --quiet   # no output, return code only

set -euo pipefail

CHECK_ONLY=0
QUIET=0
for a in "$@"; do
  case "$a" in
    --check) CHECK_ONLY=1 ;;
    --quiet) QUIET=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
  esac
done

say() { (( QUIET )) || echo "$*"; }
err() { (( QUIET )) || echo "$*" >&2; }

YABAI=$(command -v yabai) || { err "yabai not installed"; exit 2; }
HASH=$(shasum -a 256 "$YABAI" | cut -d' ' -f1)
EXPECTED="$(whoami) ALL=(root) NOPASSWD: sha256:$HASH $YABAI --load-sa"
SUDOERS=/private/etc/sudoers.d/yabai

current=""
[[ -r "$SUDOERS" ]] && current=$(sudo cat "$SUDOERS" 2>/dev/null || true)

if [[ "$current" == "$EXPECTED" ]]; then
  say "✓ yabai sudoers entry up-to-date (hash $HASH)"
  exit 0
fi

(( CHECK_ONLY )) && {
  err "✗ yabai sudoers entry stale or missing (run: $0)"
  exit 1
}

say "Writing sudoers entry for yabai (hash $HASH)…"
echo "$EXPECTED" | sudo tee "$SUDOERS" >/dev/null
sudo chmod 440 "$SUDOERS"
say "✓ updated $SUDOERS"
