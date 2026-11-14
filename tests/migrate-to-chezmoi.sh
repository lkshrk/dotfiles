#!/usr/bin/env bash
# A host after pulling the chezmoi layout: Stow links dangle, one reaches an untracked file. The migration must fix all.
set -euo pipefail

src=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
git clone -q "$src" "$work/repo"
repo=$work/repo
fake_home=$work/home
mkdir -p "$fake_home"

# The last commit before the chezmoi layout holds the old dotfiles/<package>/ tree.
before=$(git -C "$src" rev-list -1 HEAD -- .chezmoiroot)^
git -C "$src" ls-tree -r --name-only "$before" -- dotfiles | python3 -I -c '
import os, sys
repo, home = sys.argv[1], sys.argv[2]
skip = {"git@apm3ljhmvg7xgcf", "zshrc@topaz", "nvim-plantuml.lua@apm3ljhmvg7xgcf", "omni-apm", "omni-apm@topaz"}
for path in sys.stdin.read().splitlines():
    package, rel = path.split("/", 2)[1:]
    if package in skip:
        continue
    link = os.path.join(home, rel)
    if os.path.lexists(link):
        continue
    os.makedirs(os.path.dirname(link), exist_ok=True)
    os.symlink(os.path.relpath(os.path.join(repo, path), os.path.dirname(link)), link)
' "$repo" "$fake_home"

mkdir -p "$repo/dotfiles/gh/.config/gh" "$fake_home/.config/gh"
printf 'github.com:\n  user: test\n' > "$repo/dotfiles/gh/.config/gh/hosts.yml"
ln -sfn ../../../repo/dotfiles/gh/.config/gh/hosts.yml "$fake_home/.config/gh/hosts.yml"
wants=$fake_home/.config/systemd/user/graphical-session.target.wants
mkdir -p "$wants"
ln -s "$repo/dotfiles/systemd-user/.config/systemd/user/ha-doorbell.service" "$wants/ha-doorbell.service"

# The test must never change the real host: these fail the run if anything reaches for them.
guard=$work/guard
mkdir -p "$guard"
for tool in pkexec sudo yay brew mise pacman; do
  printf '#!/bin/sh\necho "test touched the host: %s $*" >&2\nexit 99\n' "$tool" > "$guard/$tool"
  chmod +x "$guard/$tool"
done

run() {
  env -u XDG_CONFIG_HOME -u XDG_STATE_HOME -u XDG_DATA_HOME HOME="$fake_home" DOTFILES_HOST=towerr \
    PATH="$guard:$PATH" "$repo/scripts/migrate-to-chezmoi.sh" "$@"
}
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

run --dry-run > "$work/dry.log"
grep -qE '[1-9][0-9]+ dangling.*, 1 to untracked repo files' "$work/dry.log" || fail "dry run did not see the old links"
[ -L "$fake_home/.config/hypr/hyprland.lua" ] || fail "dry run changed files"

run --yes --no-services > "$work/run.log" 2>&1 || { cat "$work/run.log"; fail "migration failed"; }

[ -f "$fake_home/.config/gh/hosts.yml" ] && [ ! -L "$fake_home/.config/gh/hosts.yml" ] || fail "gh hosts.yml is not a real file"
grep -q 'user: test' "$fake_home/.config/gh/hosts.yml" || fail "gh hosts.yml lost its content"
[ ! -e "$repo/dotfiles/gh/.config/gh/hosts.yml" ] || fail "repo copy of hosts.yml was not removed"
[ -f "$fake_home/.config/hypr/hyprland.lua" ] && [ ! -L "$fake_home/.config/hypr/hyprland.lua" ] || fail "hyprland.lua is not a copy"
[ "$(readlink "$wants/ha-doorbell.service")" = "$fake_home/.config/systemd/user/ha-doorbell.service" ] || fail "wants link not re-linked"
[ -x "$fake_home/.config/env/bin/agent-run" ] || fail "agent-run lost its executable bit"
if find "$fake_home" -type l -lname '*repo/dotfiles/*' | grep -q .; then
  fail "old links remain"
fi

run --yes --no-services > "$work/rerun.log" 2>&1 || { cat "$work/rerun.log"; fail "second run failed"; }
grep -q '0 dangling' "$work/rerun.log" || fail "second run found work to do"

printf '%s\n' "PASS: migration copies leftovers, applies chezmoi, re-links units, removes stale links, verifies, reruns cleanly"
