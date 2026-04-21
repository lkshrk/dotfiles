#!/usr/bin/env bash
# scripts/sync.sh — keep dotfiles repo and $HOME in sync.
#
# Does NOT add new files to the repo. Use scripts/track.sh for that.
#
# Phases:
#   1. ADOPT — `stow --adopt` per package. Absorbs drift on already-tracked
#      files when the symlink got clobbered by an atomic write at $HOME.
#   2. RESTOW — rebuild symlinks.
#   3. COMMIT — auto-commit any staged changes (skip with --no-commit).
#
# Usage:
#   ./scripts/sync.sh                # interactive, auto-commits at end
#   ./scripts/sync.sh --dry-run      # report only, no writes, no commit
#   ./scripts/sync.sh --yes          # no prompts (use in cron / hooks)
#   ./scripts/sync.sh --no-commit    # absorb + restow only, leave changes staged

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DOTFILES_DIR"

PACKAGES=(
  brew zsh git gh nvim ghostty tmux hammerspoon
  linearmouse skhd yabai zed ssh claude opencode
)

DRY_RUN=0
ASSUME_YES=0
COMMIT=1
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n)   DRY_RUN=1 ;;
    --yes|-y)       ASSUME_YES=1 ;;
    --no-commit)    COMMIT=0 ;;
    -h|--help)
      sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

c_red='\033[31m'; c_yel='\033[33m'; c_grn='\033[32m'; c_dim='\033[2m'; c_off='\033[0m'
say()  { printf '%b\n' "$*"; }
info() { say "${c_dim}  $*${c_off}"; }
warn() { say "${c_yel}! $*${c_off}"; }
ok()   { say "${c_grn}✓ $*${c_off}"; }
err()  { say "${c_red}✗ $*${c_off}" >&2; }

confirm() {
  (( ASSUME_YES )) && return 0
  local prompt="$1" reply
  read -r -p "$prompt [y/N] " reply </dev/tty
  [[ "$reply" =~ ^[Yy]$ ]]
}

stow_adopt_and_restow() {
  local pkg="$1"
  if (( DRY_RUN )); then
    info "would run: stow --adopt --no-folding -t $HOME $pkg"
    info "would run: stow -R    --no-folding -t $HOME $pkg"
    return 0
  fi

  # Check for conflicts before doing anything
  while IFS= read -r -d '' src; do
    local rel="${src#$DOTFILES_DIR/$pkg/}"
    local target="$HOME/$rel"

    # Skip if target doesn't exist or is already a symlink
    [[ -e "$target" && ! -L "$target" ]] || continue

    # Check if files differ
    if ! cmp -s "$src" "$target"; then
      warn "conflict: $target differs from repo"
      echo "  repo version: $src"
      echo "  local version: $target"
      if ! confirm "  overwrite local version with repo version?"; then
        info "  keeping local version; skipping $pkg"
        return 0
      fi
      # Back up local version
      local backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$backup_dir/$(dirname "$rel")"
      cp -p "$target" "$backup_dir/$rel"
      info "  backed up local version to $backup_dir/$rel"
    fi
  done < <(find "$DOTFILES_DIR/$pkg" -type f -not -path '*/.git/*' -print0)

  # Now safe to restow
  stow -R --no-folding -t "$HOME" "$pkg" 2>&1 | sed "s/^/  /" || {
    err "$pkg: restow failed"
    return 1
  }
}

command -v stow >/dev/null || { err "GNU stow not installed"; exit 1; }

(( DRY_RUN )) && warn "dry-run mode: no changes will be made"

say "${c_dim}── Phase 1: adopt drift + restow ──${c_off}"
for pkg in "${PACKAGES[@]}"; do
  [[ -d "$DOTFILES_DIR/$pkg" ]] || { warn "skip missing package: $pkg"; continue; }
  say "${c_dim}$pkg${c_off}"
  stow_adopt_and_restow "$pkg" || err "  $pkg failed"
done

if (( COMMIT )) && (( ! DRY_RUN )); then
  say "${c_dim}── Phase 2: commit ──${c_off}"
  cd "$DOTFILES_DIR"
  if [[ -z "$(git status --porcelain)" ]]; then
    info "nothing to commit"
  else
    local_pkgs=$(git status --porcelain \
                  | awk '{print $2}' \
                  | awk -F/ '{print $1}' \
                  | sort -u \
                  | paste -sd ',' -)
    msg="chore(dotsync): $local_pkgs ($(date +%Y-%m-%d))"
    git add -A
    git commit -m "$msg" | sed "s/^/  /"
    ok "committed: $msg"
  fi
fi

if (( ! DRY_RUN )); then
  mkdir -p "$HOME/.cache/zsh"
  touch "$HOME/.cache/zsh/dotfiles-last-sync"
  printf 'no\n' > "$HOME/.cache/zsh/dotfiles-drift-check"
fi

ok "sync complete"
