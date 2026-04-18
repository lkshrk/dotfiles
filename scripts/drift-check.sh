#!/usr/bin/env bash
# scripts/drift-check.sh — write yes/no to the drift cache.
#
# "yes" if any of these is true:
#   1. the repo has uncommitted changes (git status --porcelain not empty).
#   2. any file tracked under a stow package exists in $HOME as a real
#      (non-symlink) file — i.e. a symlink got clobbered by an atomic write
#      and `stow --adopt` needs to pull the edit back.
#   3. any $HOME path next to a tracked file is a new, untracked candidate
#      that would NOT be gitignored if it were moved into the repo — i.e.
#      something you probably want to `scripts/track.sh`.
#
# Called in the background by 80-sync-reminder.zsh once the 30-day
# threshold is hit. Intentionally silent on stdout/stderr; writes only
# to the cache file. Use `--list` for a human-readable report.

set -u

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Dev/dotfiles}"
CACHE="$HOME/.cache/zsh/dotfiles-drift-check"
LIST=0

for arg in "$@"; do
  case "$arg" in
    --list|-l) LIST=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$(dirname "$CACHE")"

# Collect the set of $HOME directories that already contain at least one
# symlink into the repo. Those are the only dirs we consider "tracked" for
# the purpose of suggesting new-file candidates — this keeps the scan
# bounded to places that clearly belong to a stow package.
declare -a TRACKED_HOME_DIRS=()
while IFS= read -r -d '' src; do
  rel="${src#$DOTFILES_DIR/}"
  # Strip the package name (first path component) to get the $HOME-relative path.
  [[ "$rel" == */* ]] || continue
  pkg_name="${rel%%/*}"
  rel_in_pkg="${rel#$pkg_name/}"
  target="$HOME/$rel_in_pkg"
  [[ -L "$target" ]] || continue
  home_dir="$(dirname "$target")"
  # Skip $HOME itself — too noisy (history files, runtime crumbs, etc.).
  # Top-level dotfiles should be added explicitly via scripts/track.sh.
  [[ "$home_dir" == "$HOME" ]] && continue
  # Avoid duplicates.
  dup=0
  for d in "${TRACKED_HOME_DIRS[@]:-}"; do
    [[ "$d" == "$home_dir" ]] && { dup=1; break; }
  done
  (( dup )) || TRACKED_HOME_DIRS+=("$home_dir")
done < <(find "$DOTFILES_DIR" -type f -not -path '*/.git/*' -print0 2>/dev/null)

# Resolve a relative symlink target to an absolute path (best effort; macOS
# lacks `readlink -f`).
resolve_link() {
  local link="$1" target
  target=$(readlink "$link") || return 1
  if [[ "$target" = /* ]]; then
    printf '%s\n' "$target"
  else
    printf '%s\n' "$(cd "$(dirname "$link")" 2>/dev/null && cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
  fi
}

new_candidates=()
for home_dir in "${TRACKED_HOME_DIRS[@]:-}"; do
  [[ -d "$home_dir" ]] || continue
  # Pick one symlink in this dir, follow it, use its repo location to infer
  # which package owns $home_dir.
  pkg_root=""
  for entry in "$home_dir"/* "$home_dir"/.[!.]*; do
    [[ -L "$entry" ]] || continue
    tgt=$(resolve_link "$entry") || continue
    [[ "$tgt" == "$DOTFILES_DIR"/* ]] || continue
    pkg_root="${tgt#$DOTFILES_DIR/}"
    pkg_root="${pkg_root%%/*}"
    break
  done
  [[ -n "$pkg_root" ]] || continue

  rel_base="${home_dir#"$HOME"/}"
  pkg_dir_in_repo="$DOTFILES_DIR/$pkg_root/$rel_base"

  for entry in "$home_dir"/* "$home_dir"/.[!.]*; do
    [[ -e "$entry" ]] || continue
    [[ -L "$entry" ]] && continue
    [[ -f "$entry" ]] || continue
    name="${entry##*/}"
    dst_in_repo="$pkg_dir_in_repo/$name"
    [[ -e "$dst_in_repo" ]] && continue
    # Skip if it would be gitignored.
    git -C "$DOTFILES_DIR" check-ignore -q "$dst_in_repo" && continue
    new_candidates+=("$entry|$pkg_root")
  done
done

# Determine drift state.
has_drift=0

if [[ -d "$DOTFILES_DIR/.git" ]] \
   && [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null)" ]]; then
  has_drift=1
fi

if (( ! has_drift )); then
  while IFS= read -r -d '' src; do
    rel="${src#$DOTFILES_DIR/}"
    [[ "$rel" == */* ]] || continue
    pkg_name="${rel%%/*}"
    rel_in_pkg="${rel#$pkg_name/}"
    target="$HOME/$rel_in_pkg"
    if [[ -e "$target" && ! -L "$target" ]]; then
      has_drift=1
      break
    fi
  done < <(find "$DOTFILES_DIR" -type f -not -path '*/.git/*' -print0 2>/dev/null)
fi

# Scan ~/.config for subdirs that have no corresponding stow package in the
# repo and would NOT be gitignored if they were added. These are candidates
# for a brand-new package rather than new files in an existing one.
unknown_pkgs=()
if [[ -d "$HOME/.config" ]]; then
  while IFS= read -r -d '' sub; do
    name="${sub##*/}"
    # Skip if a repo package already tracks this .config subdir.
    any_pkg=0
    for pkg in "$DOTFILES_DIR"/*/; do
      [[ -d "${pkg}.config/$name" ]] && { any_pkg=1; break; }
    done
    (( any_pkg )) && continue
    # Skip if the hypothetical repo path is gitignored. Trailing slash matters
    # because gitignore entries end with `/` to scope to directories.
    hypo="$name/.config/$name/"
    git -C "$DOTFILES_DIR" check-ignore -q "$hypo" && continue
    unknown_pkgs+=("$sub")
  done < <(find "$HOME/.config" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
fi

(( ${#new_candidates[@]:-0} > 0 )) && has_drift=1
(( ${#unknown_pkgs[@]:-0} > 0 ))   && has_drift=1

if (( LIST )); then
  printf '── repo drift ──\n'
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    status=$(git -C "$DOTFILES_DIR" status --porcelain)
    if [[ -n "$status" ]]; then
      printf '%s\n' "$status"
    else
      printf '  (clean)\n'
    fi
  fi
  printf '\n── new $HOME candidates (not gitignored) ──\n'
  if (( ${#new_candidates[@]:-0} == 0 )); then
    printf '  (none)\n'
  else
    for entry in "${new_candidates[@]}"; do
      path="${entry%|*}"
      pkg="${entry##*|}"
      printf '  %s  → pkg: %s\n' "$path" "$pkg"
    done
    printf '\nstart tracking one with: scripts/track.sh <path>\n'
  fi

  printf '\n── unknown ~/.config subdirs (no package yet, not gitignored) ──\n'
  if (( ${#unknown_pkgs[@]:-0} == 0 )); then
    printf '  (none)\n'
  else
    for sub in "${unknown_pkgs[@]}"; do
      printf '  %s\n' "$sub"
    done
    printf '\nstart tracking as a new package with: scripts/track.sh <path>\n'
    printf 'or gitignore with e.g.:  echo "<name>/.config/<name>/" >> .gitignore\n'
  fi
fi

if (( has_drift )); then
  printf 'yes\n' > "$CACHE"
else
  printf 'no\n' > "$CACHE"
fi
