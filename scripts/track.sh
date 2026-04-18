#!/usr/bin/env bash
# scripts/track.sh — start tracking a file or directory that currently lives
# under $HOME. Moves it into the correct stow package, restows so the original
# path becomes a symlink back into the repo, and stages it for commit.
#
# Usage:
#   scripts/track.sh <$HOME path> [package]
#   scripts/track.sh ~/.config/aerospace/aerospace.toml
#   scripts/track.sh ~/.config/aerospace/aerospace.toml aerospace
#
# If [package] is omitted the script derives it:
#   ~/.config/<name>/...  →  package <name> (auto-creates the dir if missing)
#   ~/.<name>...          →  looks for an existing package that tracks it,
#                            otherwise asks you to pass one explicitly.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

c_red='\033[31m'; c_yel='\033[33m'; c_grn='\033[32m'; c_dim='\033[2m'; c_off='\033[0m'
say()  { printf '%b\n' "$*"; }
info() { say "${c_dim}  $*${c_off}"; }
warn() { say "${c_yel}! $*${c_off}"; }
ok()   { say "${c_grn}✓ $*${c_off}"; }
err()  { say "${c_red}✗ $*${c_off}" >&2; }

usage() { sed -n '2,15p' "$0"; exit "${1:-0}"; }

[[ $# -ge 1 && $# -le 2 ]] || usage 2
case "$1" in -h|--help) usage 0 ;; esac

raw="$1"
pkg="${2:-}"

# Resolve to an absolute path and verify it lives under $HOME.
if [[ "$raw" = /* ]]; then
  target="$raw"
else
  target="$(pwd)/$raw"
fi
# Normalize (.. and .) without requiring the file to exist via cd+pwd on parent.
parent="$(cd "$(dirname "$target")" && pwd)"
target="$parent/$(basename "$target")"

[[ -e "$target" ]] || { err "not found: $target"; exit 1; }
[[ -L "$target" ]] && { err "already a symlink: $target"; exit 1; }
case "$target" in
  "$HOME"/*) ;;
  *) err "must live under \$HOME: $target"; exit 1 ;;
esac

rel="${target#"$HOME"/}"

# Derive package if not given.
#   ~/.config/<name>/...  →  <name>
#   ~/.<name>/...         →  <name>  (e.g. .claude, .ssh)
#   anything else         →  look up an existing package that already contains
#                            this relative path, or bail.
if [[ -z "$pkg" ]]; then
  case "$rel" in
    .config/*/*)
      pkg="${rel#.config/}"
      pkg="${pkg%%/*}"
      ;;
    .*/*)
      pkg="${rel%%/*}"
      pkg="${pkg#.}"
      ;;
    *)
      for candidate in "$DOTFILES_DIR"/*/; do
        candidate="${candidate%/}"
        candidate="${candidate##*/}"
        [[ -e "$DOTFILES_DIR/$candidate/$rel" ]] && { pkg="$candidate"; break; }
      done
      if [[ -z "$pkg" ]]; then
        err "can't derive package for $rel — pass it explicitly as arg 2"
        exit 1
      fi
      ;;
  esac
fi

dst="$DOTFILES_DIR/$pkg/$rel"

if [[ -e "$dst" ]]; then
  err "already exists in repo: $dst"
  exit 1
fi

command -v stow >/dev/null || { err "GNU stow not installed"; exit 1; }

say "${c_dim}package:${c_off} $pkg"
say "${c_dim}source: ${c_off} $target"
say "${c_dim}dest:   ${c_off} $dst"

# Respect repo .gitignore: warn if the destination would be ignored. This
# usually means you meant to edit the .gitignore, not start tracking the file.
if git -C "$DOTFILES_DIR" check-ignore -q "$dst"; then
  warn "destination is matched by repo .gitignore"
  info "file will still be tracked by stow but git won't see it"
fi

mkdir -p "$(dirname "$dst")"
mv "$target" "$dst"

# Restow so the original path becomes a symlink into the repo.
stow -R --no-folding -t "$HOME" "$pkg" 2>&1 | sed "s/^/  /" || {
  err "stow restow failed; file was moved to $dst, restore manually"
  exit 1
}

# Stage it if git sees it. Nothing to do if gitignored.
if ! git -C "$DOTFILES_DIR" check-ignore -q "$dst"; then
  git -C "$DOTFILES_DIR" add -- "$dst"
  ok "tracked + staged: $dst"
else
  ok "tracked (gitignored, not staged): $dst"
fi
