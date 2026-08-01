#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval "$(sed -n '/^gii()/,/^}/p' "$repo_dir/dotfiles/zsh/.config/zsh/60-functions.zsh")"

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/home/.config/zsh/templates" "$test_dir/project"
printf 'shared\nfrom-template\nshared\n' > "$test_dir/home/.config/zsh/templates/default.gitignore"
printf 'existing\nshared\nexisting\n' > "$test_dir/project/.gitignore"

(
  cd "$test_dir/project"
  HOME="$test_dir/home" gii
)

printf 'existing\nshared\nfrom-template\n' > "$test_dir/expected"
cmp "$test_dir/expected" "$test_dir/project/.gitignore"

printf 'PASS: gii merges unique gitignore entries\n'
