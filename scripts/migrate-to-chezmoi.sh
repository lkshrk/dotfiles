#!/usr/bin/env bash
# Usage: scripts/migrate-to-chezmoi.sh [--dry-run] [--yes] [--no-services]
# Moves this host from Stow symlinks to chezmoi copies, then verifies. Run after pulling the chezmoi layout.
#   --dry-run      show the plan, change nothing
#   --yes          don't ask before changing files
#   --no-services  skip systemd/launchd reloads, chezmoi scripts and the Hyprland check (tests)
# DOTFILES_HOST overrides the hostname used to pick the host's groups.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
dry_run=0 assume_yes=0 services=1 failures=0
for arg in "$@"; do
  case $arg in
    --dry-run) dry_run=1 ;;
    --yes | -y) assume_yes=1 ;;
    --no-services) services=0 ;;
    -h | --help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

say() { printf '==> %s\n' "$*"; }
ok() { printf '  ok   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*" >&2; failures=$((failures + 1)); }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v chezmoi >/dev/null 2>&1 || die "chezmoi is not installed"
command -v python3 >/dev/null 2>&1 || die "python3 is required"
[ -f "$repo/.chezmoiroot" ] || die "$repo has no .chezmoiroot; pull the chezmoi layout first"

host=$(chezmoi --source "$repo" execute-template '{{ env "DOTFILES_HOST" | default .chezmoi.hostname | lower }}')
grep -q "^  $host:" "$repo/home/.chezmoidata/hosts.yaml" || die "host '$host' is not listed in home/.chezmoidata/hosts.yaml"

config="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
if [ -f "$config" ] && ! grep -qF "sourceDir = \"$repo\"" "$config"; then
  die "$config points chezmoi at another source; fix or remove it first"
fi

# Prints: <class> TAB <link> TAB <absolute target>. Classes: leftover (target exists), dangling.
scan_links() {
  python3 -I - "$HOME" "$repo" <<'EOF'
import os, sys
home, repo = sys.argv[1], sys.argv[2]
old = os.path.join(repo, "dotfiles") + os.sep
skip_names = {".git", "node_modules", ".cache", "Trash", "Caches", "mise", ".cargo", ".rustup", "go", ".npm", ".bun",
              ".oh-my-zsh", "Steam", ".wine", "Containers", "Group Containers"}
for root, dirs, files in os.walk(home):
    rel = os.path.relpath(root, home)
    depth = 0 if rel == "." else rel.count(os.sep) + 1
    if root == repo or root.startswith(repo + os.sep) or depth >= 8:
        dirs[:] = []
    dirs[:] = [d for d in dirs if d not in skip_names
               and not (rel == "Library" and d not in {"LaunchAgents"})
               and not (rel == "." and d == "Dev")]
    for name in dirs + files:
        path = os.path.join(root, name)
        if not os.path.islink(path):
            continue
        target = os.path.normpath(os.path.join(root, os.readlink(path)))
        if not target.startswith(old):
            continue
        if os.path.isfile(target):
            cls = "leftover"
        else:
            cls = "dangling"
        print(f"{cls}\t{path}\t{target}")
EOF
}

untracked() { ! git -C "$repo" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }

say "host $host, source $repo"
plan=$(scan_links)
count() { printf '%s\n' "$plan" | grep -c "^$1	" || true; }
leftovers=$(count leftover) dangling=$(count dangling)
printf '  old links: %s dangling (chezmoi replaces or they are removed), %s to untracked repo files (copied into place)\n' \
  "$dangling" "$leftovers"
printf '%s\n' "$plan" | awk -F'\t' '$1=="leftover" {print "    copy  " $2}'
managed=$(chezmoi --source "$repo" --override-data "{\"host\":\"$host\"}" managed --include=files,symlinks | wc -l | tr -d ' ')
printf '  chezmoi will manage %s files for %s\n' "$managed" "$host"

if ((dry_run)); then
  say "dry run: nothing changed"
  exit 0
fi
if ((!assume_yes)); then
  read -r -p "Replace the links with chezmoi copies now? [y/N] " answer
  [[ $answer == [yY]* ]] || die "aborted"
fi

state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-migration/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$state"
printf '%s\n' "$plan" > "$state/links.tsv"
say "old links recorded in $state/links.tsv"

say "copying files that old links still reach"
printf '%s\n' "$plan" | while IFS=$'\t' read -r cls link target; do
  [ "$cls" = leftover ] || continue
  cp -p --remove-destination "$target" "$link" 2>/dev/null || { rm -f "$link" && cp -p "$target" "$link"; }
  ok "$link"
done

say "chezmoi apply"
# --no-services also skips chezmoi's scripts (package installs) and externals: tests must not change the host.
skip=()
((services)) || skip=(--exclude=scripts,externals)
# `init --apply` ignores --exclude, so init and apply run separately.
chezmoi init --source "$repo" --no-tty
chezmoi apply --force --no-tty ${skip[@]+"${skip[@]}"}
ok "applied"

say "remaining old links"
scan_links | while IFS=$'\t' read -r cls link target; do
  [ "$cls" = dangling ] || continue
  case $link in
    */systemd/user/*.wants/*)
      unit="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$(basename "$link")"
      if [ -f "$unit" ]; then
        ln -sfn "$unit" "$link"
        ok "re-linked $(basename "$link") to the unit file"
        continue
      fi
      ;;
  esac
  rm -f "$link"
  ok "removed stale $link"
done

if ((services)); then
  case $(uname -s) in
    Linux)
      systemctl --user daemon-reload 2>/dev/null && ok "systemd user daemon reloaded" || true
      ;;
    Darwin)
      for plist in "$HOME"/Library/LaunchAgents/com.lkshrk.*.plist; do
        [ -f "$plist" ] || continue
        label=$(basename "$plist" .plist)
        launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
        launchctl bootstrap "gui/$(id -u)" "$plist" && ok "reloaded $label" || bad "could not load $label"
      done
      ;;
  esac
fi

say "verify"
chezmoi verify --no-tty ${skip[@]+"${skip[@]}"} >/dev/null 2>&1 && ok "chezmoi verify: every managed file matches the repo" || bad "chezmoi verify found differences (run: chezmoi diff)"
status=$(chezmoi status --no-tty ${skip[@]+"${skip[@]}"} 2>/dev/null || true)
[ -z "$status" ] && ok "chezmoi status is clean" || bad "chezmoi status reports $(printf '%s\n' "$status" | wc -l | tr -d ' ') entries"
after=$(scan_links)
stale=$(printf '%s\n' "$after" | grep -cv '^$' || true)
[ "$stale" = 0 ] && ok "no old links left" || bad "$stale old links left (see: $0 --dry-run)"
broken_wants=$(find "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user" -path '*.wants/*' -xtype l 2>/dev/null | wc -l | tr -d ' ')
[ "$broken_wants" = 0 ] && ok "systemd .wants links resolve" || bad "$broken_wants dangling systemd .wants links"
if ((services)) && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
  errors=$(hyprctl configerrors 2>/dev/null | grep -v '^$' || true)
  [ -z "$errors" ] && ok "Hyprland reports no config errors" || bad "Hyprland config errors: $errors"
fi

if ((failures)); then
  say "$failures check(s) failed; old links are listed in $state/links.tsv"
  exit 1
fi

say "removing repo copies of files now in place"
printf '%s\n' "$plan" | while IFS=$'\t' read -r cls link target; do
  [ "$cls" = leftover ] || continue
  if untracked "$target" && cmp -s "$target" "$link"; then
    rm -f "$target"
    ok "removed $target"
  fi
done
find "$repo/dotfiles" -mindepth 1 -type d -empty -delete 2>/dev/null || true
say "done: $host now uses chezmoi copies"
! command -v omni >/dev/null 2>&1 || say "omni is no longer used: remove it (brew uninstall omni, or ~/.local/bin/omni) and ~/.config/omni, ~/.local/share/omni, ~/.local/state/omni, ~/.cache/omni"
