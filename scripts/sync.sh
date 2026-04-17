#!/usr/bin/env bash
# scripts/sync.sh — keep dotfiles repo and $HOME in sync.
#
# Three phases per package:
#   1. ADOPT_NEW — for packages where the whole dir is tracked, copy any new
#      files from $HOME into the repo (e.g. you add a hammerspoon .lua via Finder).
#   2. ADOPT_DRIFT — for any tracked file that exists in $HOME as a regular
#      file (symlink was clobbered by atomic write), absorb its current
#      contents back into the repo via `stow --adopt`.
#   3. RESTOW — re-create symlinks so $HOME points back at the repo.
#   4. COMMIT — auto-commit any staged changes (skip with --no-commit).
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
  linearmouse skhd yabai zed ssh claude
)

ADOPT_NEW_RULES=(
  "hammerspoon:.config/hammerspoon:-type f \\( -name '*.lua' -o -name '.luarc.json' \\) -print0"
  "yabai:.config/yabai:-type f -name '*.sh' -print0"
  "nvim:.config/nvim/lua:-type f -name '*.lua' -print0"
  "zsh:.config/zsh:-type f -name '*.zsh' ! -name '99-local.zsh' -print0"
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
      sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

c_red='\033[31m'; c_yel='\033[33m'; c_grn='\033[32m'; c_dim='\033[2m'; c_off='\033[0m'
say()  { printf '%b\n' "$*"; }
info() { say "${c_dim}  $*${c_off}"; }
warn() { say "${c_yel}! $*${c_off}"; }
ok()   { say "${c_grn}✓ $*${c_off}"; }
err()  { say "${c_red}✗ $*${c_off}" >&2; }

run() {
  if (( DRY_RUN )); then
    info "would run: $*"
  else
    "$@"
  fi
}

confirm() {
  (( ASSUME_YES )) && return 0
  local prompt="$1" reply
  read -r -p "$prompt [y/N] " reply </dev/tty
  [[ "$reply" =~ ^[Yy]$ ]]
}

adopt_new() {
  local pkg="$1" rel="$2" find_args="$3"
  local home_dir="$HOME/$rel"
  local pkg_dir="$DOTFILES_DIR/$pkg/$rel"

  [[ -d "$home_dir" ]] || return 0
  [[ -d "$pkg_dir"  ]] || run mkdir -p "$pkg_dir"

  local count=0
  while IFS= read -r -d '' src; do
    local rel_to_root="${src#$home_dir/}"
    local dst="$pkg_dir/$rel_to_root"

    [[ -L "$src" ]] && continue
    [[ -e "$dst" ]] && continue

    say "  ${c_grn}+${c_off} adopt new: $src"
    run mkdir -p "$(dirname "$dst")"
    run cp -p "$src" "$dst"
    ((count++)) || true
  done < <(eval find "\"$home_dir\"" $find_args)

  (( count > 0 )) && ok "$pkg: adopted $count new file(s)"
  return 0
}

stow_adopt_and_restow() {
  local pkg="$1"
  if (( DRY_RUN )); then
    info "would run: stow --adopt --no-folding -t $HOME $pkg"
    info "would run: stow -R    --no-folding -t $HOME $pkg"
    return 0
  fi

  local before
  before=$(git -C "$DOTFILES_DIR" status --porcelain "$pkg" 2>/dev/null || true)

  stow --adopt --no-folding -t "$HOME" "$pkg" 2>&1 | sed "s/^/  /" || {
    err "$pkg: stow --adopt failed"
    return 1
  }

  local after
  after=$(git -C "$DOTFILES_DIR" status --porcelain "$pkg" 2>/dev/null || true)

  if [[ "$before" != "$after" ]]; then
    warn "$pkg: drift absorbed into repo:"
    git -C "$DOTFILES_DIR" --no-pager diff --stat "$pkg" | sed "s/^/    /"
    if ! confirm "  inspect/keep changes for $pkg?"; then
      warn "  reverting absorbed changes for $pkg"
      git -C "$DOTFILES_DIR" checkout -- "$pkg"
    fi
  fi

  stow -R --no-folding -t "$HOME" "$pkg" 2>&1 | sed "s/^/  /" || {
    err "$pkg: restow failed"
    return 1
  }
}

command -v stow >/dev/null || { err "GNU stow not installed"; exit 1; }

(( DRY_RUN )) && warn "dry-run mode: no changes will be made"

say "${c_dim}── Phase 1: adopt new files ──${c_off}"
for rule in "${ADOPT_NEW_RULES[@]}"; do
  IFS=':' read -r pkg rel find_args <<<"$rule"
  adopt_new "$pkg" "$rel" "$find_args"
done

say "${c_dim}── Phase 2: adopt drift + restow ──${c_off}"
for pkg in "${PACKAGES[@]}"; do
  [[ -d "$DOTFILES_DIR/$pkg" ]] || { warn "skip missing package: $pkg"; continue; }
  say "${c_dim}$pkg${c_off}"
  stow_adopt_and_restow "$pkg" || err "  $pkg failed"
done

if (( COMMIT )) && (( ! DRY_RUN )); then
  say "${c_dim}── Phase 4: commit ──${c_off}"
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
