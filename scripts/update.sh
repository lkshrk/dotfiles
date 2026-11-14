#!/usr/bin/env bash
# Usage: scripts/update.sh [--check]
# Upgrades OS packages, mise tools and the dotfiles, then reports drift. --check only reports.
set -euo pipefail
export LC_ALL=C

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
check=0
case ${1:-} in
  --check) check=1 ;;
  "") ;;
  *) printf 'usage: %s [--check]\n' "$0" >&2; exit 2 ;;
esac

say() { printf '==> %s\n' "$*"; }
host=$(chezmoi execute-template '{{ .host }}')
groups=$(chezmoi execute-template '{{ index .hosts .host | default (list) | join " " }}')
lists() { for g in $groups; do [ -f "$repo/packages/$1/$g.$2" ] && printf '%s\n' "$repo/packages/$1/$g.$2"; done; }

if ((!check)); then
  case $(uname -s) in
    Darwin) say "brew"; brew update && brew upgrade ;;
    Linux) say "pacman and AUR"; yay -Syu ;;
  esac
  say "mise"; mise upgrade --yes
  say "dotfiles"; chezmoi update --no-tty
fi

say "drift on $host ($groups)"
case $(uname -s) in
  Darwin)
    brewfiles=$(lists brew Brewfile)
    if [ -n "$brewfiles" ]; then
      # shellcheck disable=SC2086
      cat $brewfiles | brew bundle check --file=- --verbose || true
      # shellcheck disable=SC2086
      cat $brewfiles | brew bundle cleanup --file=- || true
    fi
    ;;
  Linux)
    listed=$(lists arch pacman; lists arch aur)
    # shellcheck disable=SC2086
    wanted=$( { [ -z "$listed" ] || cat $listed; cat /usr/share/omarchy/install/*.packages 2>/dev/null | sed 's/#.*//' | tr -s ' \t' '\n'; } | grep -v '^$' | sort -u)
    unlisted=$(pacman -Qqe | grep -v '^omarchy' | comm -23 - <(printf '%s\n' "$wanted") || true)
    # shellcheck disable=SC2086
    missing=$( [ -z "$listed" ] || pacman -T $(cat $listed) || true)
    [ -z "$unlisted" ] && echo "  every explicit package is listed" || printf '  explicit, not listed: %s\n' "$(echo $unlisted)"
    [ -z "$missing" ] && echo "  every listed package is installed" || printf '  listed, not installed: %s\n' "$(echo $missing)"
    ;;
esac
missing_tools=$(mise ls --missing 2>/dev/null | awk -v dir="${XDG_CONFIG_HOME:-$HOME/.config}/mise" 'index($0, dir) || index($0, "~/.config/mise") {print $1}')
[ -z "$missing_tools" ] && echo "  every mise tool is installed" || printf '  mise tools missing: %s\n' "$(echo $missing_tools)"
status=$(chezmoi status --no-tty --exclude=scripts 2>/dev/null || true)
[ -z "$status" ] && echo "  dotfiles match the repo" || { echo "  dotfiles differ (chezmoi diff; dotpush to keep local edits):"; printf '%s\n' "$status" | sed 's/^/    /'; }
