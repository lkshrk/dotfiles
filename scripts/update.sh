#!/usr/bin/env bash
# Usage: scripts/update.sh [--check | --bump-apm]
# Upgrades OS packages, mise tools and the dotfiles, then reports drift. --check only reports.
# --bump-apm moves the APM git pins in apm/ai-plugins/apm.yml to each upstream's HEAD and installs them.
set -euo pipefail
export LC_ALL=C

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
check=0
bump=0
case ${1:-} in
  --check) check=1 ;;
  --bump-apm) bump=1 ;;
  "") ;;
  *) printf 'usage: %s [--check | --bump-apm]\n' "$0" >&2; exit 2 ;;
esac

say() { printf '==> %s\n' "$*"; }

if ((bump)); then
  manifest="$repo/apm/ai-plugins/apm.yml"
  say "APM pins"
  while IFS= read -r dep; do
    sha=$(git ls-remote "https://github.com/$dep.git" HEAD | cut -f1)
    [ -n "$sha" ] || { printf 'no HEAD for %s\n' "$dep" >&2; exit 1; }
    awk -v dep="$dep" -v sha="$sha" '
      /^  - / { cur = ($0 == "  - git: " dep) }
      cur && /^    ref: / { $0 = "    ref: " sha }
      { print }' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
  done < <(sed -n 's/^  - git: //p' "$manifest" | sort -fu)
  git -C "$repo" diff --stat -- "$manifest"
  apm install -g --trust-transitive-mcp
  echo "Review and commit $manifest; other hosts install the new pins on their next chezmoi apply."
  exit 0
fi

host=$(chezmoi execute-template '{{ .host }}')
groups=$(chezmoi execute-template '{{ index .hosts .host | default (list) | join " " }}')
lists() { for g in $groups; do [ -f "$repo/packages/$1/$g.$2" ] && printf '%s\n' "$repo/packages/$1/$g.$2"; done; }

if ((!check)); then
  case $(uname -s) in
    Darwin) say "brew"; brew update && brew upgrade ;;
    Linux) say "pacman and AUR"; yay -Syu ;;
  esac
  say "mise"; mise upgrade --yes
  "${XDG_CONFIG_HOME:-$HOME/.config}/env/bin/zsh-completions"
  say "dotfiles and git externals"; chezmoi update --no-tty --refresh-externals
  if command -v apm >/dev/null 2>&1 && [ -f "$HOME/.apm/apm.yml" ]; then
    say "agents (APM, pinned; bump with --bump-apm)"; apm install -g --trust-transitive-mcp
  fi
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
    # Packages the OS or Omarchy installer put on this host are theirs, not ours.
    installer="$repo/packages/installer/$host.txt"
    wanted=$( { [ -z "$listed" ] || cat $listed; [ ! -f "$installer" ] || cat "$installer"; cat /usr/share/omarchy/install/*.packages 2>/dev/null | sed 's/#.*//' | tr -s ' \t' '\n'; } | grep -v '^$' | sort -u)
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
