#!/usr/bin/env bash
# scripts/volatile-dots.sh - keep workspace-mutated dotfiles as real copies.
# Files in volatile-dots.txt are rewritten by setup or their tools, so omni
# does not manage them; their shared defaults live under templates/.
#
# Usage:
#   volatile-dots.sh prepare   before dots sync: move real files aside so stow links cleanly
#   volatile-dots.sh detach    after dots sync: replace symlinks with real copies, and seed
#                              missing files from templates/ without overwriting local ones

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="$REPO_DIR/scripts/volatile-dots.txt"

home_path() {
  # <dotfiles|templates>/<package>/<home-relative path> -> $HOME/<home-relative path>
  local rel="${1#*/}"
  printf '%s/%s\n' "$HOME" "${rel#*/}"
}

mode="${1:-}"
[[ "$mode" == "prepare" || "$mode" == "detach" ]] || {
  echo "usage: $0 prepare|detach" >&2
  exit 2
}

shift

while IFS= read -r entry; do
  [[ -n "$entry" && "$entry" != \#* ]] || continue
  if [[ $# -gt 0 ]]; then
    package="${entry#*/}"
    package="${package%%/*}"
    selected=0
    for requested in "$@"; do
      [[ "$package" != "$requested" ]] || selected=1
    done
    [[ "$selected" == 1 ]] || continue
  fi
  target="$(home_path "$entry")"
  template="$REPO_DIR/$entry"
  case "$mode" in
    prepare)
      if [[ -e "$target" && ! -L "$target" ]]; then
        mv -f "$target" "$target.pre-sync"
      fi
      ;;
    detach)
      if [[ -e "$target.pre-sync" ]]; then
        rm -f "$target"
        mv -f "$target.pre-sync" "$target"
      elif [[ -L "$target" && -e "$target" ]]; then
        src="$(readlink -f "$target")"
        rm -f "$target"
        cp -p "$src" "$target"
      elif [[ ! -e "$target" && -f "$template" ]]; then
        # Also replaces a dangling link left by a template that moved.
        rm -f "$target"
        mkdir -p "$(dirname "$target")"
        cp -p "$template" "$target"
      fi
      ;;
  esac
done < "$LIST"
