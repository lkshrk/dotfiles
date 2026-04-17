#!/usr/bin/env bash
# scripts/drift-check.sh — write yes/no to the drift cache.
#
# "yes" if either of these is true:
#   1. the repo has uncommitted changes (git status --porcelain not empty)
#   2. any file tracked under a stow package exists in $HOME as a real
#      (non-symlink) file — i.e. an adoption candidate
#
# Called in the background by 80-sync-reminder.zsh once the 30-day
# threshold is hit. Intentionally silent on stdout/stderr; writes only
# to the cache file.

set -u

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Dev/dotfiles}"
CACHE="$HOME/.cache/zsh/dotfiles-drift-check"

mkdir -p "$(dirname "$CACHE")"

has_drift=0

# 1) uncommitted changes in the repo
if [[ -d "$DOTFILES_DIR/.git" ]] \
   && [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null)" ]]; then
  has_drift=1
fi

# 2) adoption candidates: tracked files that exist in $HOME as real files
if (( ! has_drift )); then
  pkgs=(brew zsh git gh nvim ghostty tmux hammerspoon linearmouse skhd yabai zed ssh claude)
  for pkg in "${pkgs[@]}"; do
    [[ -d "$DOTFILES_DIR/$pkg" ]] || continue
    while IFS= read -r -d '' src; do
      rel="${src#$DOTFILES_DIR/$pkg/}"
      target="$HOME/$rel"
      if [[ -e "$target" && ! -L "$target" ]]; then
        has_drift=1
        break 2
      fi
    done < <(find "$DOTFILES_DIR/$pkg" -type f -not -path '*/.git/*' -print0 2>/dev/null)
  done
fi

if (( has_drift )); then
  printf 'yes\n' > "$CACHE"
else
  printf 'no\n' > "$CACHE"
fi
