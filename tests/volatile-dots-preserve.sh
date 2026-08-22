#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME=$tmp/home

source_file=$repo_dir/dotfiles/claude/.claude/settings.json
target=$HOME/.claude/settings.json
mkdir -p "$(dirname "$target")"

ln -s "$source_file" "$target"
"$repo_dir/scripts/volatile-dots.sh" detach
test -f "$target" -a ! -L "$target"
cmp "$source_file" "$target"

printf 'live-change\n' > "$target"
"$repo_dir/scripts/volatile-dots.sh" prepare
test -f "$target.pre-sync"
ln -s "$source_file" "$target"
"$repo_dir/scripts/volatile-dots.sh" detach
grep -qx live-change "$target"
test ! -e "$target.pre-sync"

"$repo_dir/scripts/volatile-dots.sh" prepare
test ! -e "$target"
"$repo_dir/scripts/volatile-dots.sh" detach
grep -qx live-change "$target"

printf 'PASS: volatile dotfiles preserve live workspace state\n'
