#!/usr/bin/env bash
# scripts/volatile-dots.sh - keep runtime-mutated dotfiles as real copies.
# Files in volatile-dots.txt are rewritten by their tools at runtime; as stow
# symlinks those writes would dirty the repo checkout.
#
# Usage:
#   volatile-dots.sh prepare   before dots sync: move real files aside so stow links cleanly
#   volatile-dots.sh detach    after dots sync: replace stowed symlinks with real copies

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="$REPO_DIR/scripts/volatile-dots.txt"

home_path() {
  # dotfiles/<package>/<home-relative path> -> $HOME/<home-relative path>
  local rel="${1#dotfiles/}"
  printf '%s/%s\n' "$HOME" "${rel#*/}"
}

mode="${1:-}"
[[ "$mode" == "prepare" || "$mode" == "detach" ]] || {
  echo "usage: $0 prepare|detach" >&2
  exit 2
}

while IFS= read -r entry; do
  [[ -n "$entry" && "$entry" != \#* ]] || continue
  target="$(home_path "$entry")"
  case "$mode" in
    prepare)
      if [[ -e "$target" && ! -L "$target" ]]; then
        mv -f "$target" "$target.pre-sync"
      fi
      ;;
    detach)
      if [[ -L "$target" ]]; then
        src="$(readlink -f "$target")"
        rm -f "$target"
        cp -p "$src" "$target"
      fi
      ;;
  esac
done < "$LIST"
