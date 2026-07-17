#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAPTURE_SCRIPT="$REPO_DIR/scripts/capture-coder-dotfiles"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export CODER_DOTFILES_SOURCE_DIR="$HOME/dotfiles"
export CODER_DOTFILES_RUNTIME_DIR="$HOME/.local/share/dotfiles-runtime"
seed="$TEST_ROOT/seed"
mkdir -p "$HOME/.local/share"

git init --quiet --initial-branch=main "$seed"
git -C "$seed" config user.name test
git -C "$seed" config user.email test@example.invalid
git -C "$seed" config commit.gpgsign false
printf 'base\n' >"$seed/tracked.txt"
printf 'base\n' >"$seed/conflict.txt"
printf 'base\n' >"$seed/all.txt"
git -C "$seed" add tracked.txt conflict.txt all.txt
git -C "$seed" commit --quiet -m initial
git clone --quiet "$seed" "$CODER_DOTFILES_SOURCE_DIR"
git clone --quiet "$seed" "$CODER_DOTFILES_RUNTIME_DIR"

printf 'runtime\n' >"$CODER_DOTFILES_RUNTIME_DIR/tracked.txt"
printf 'runtime\n' >"$CODER_DOTFILES_RUNTIME_DIR/conflict.txt"
printf 'runtime\n' >"$CODER_DOTFILES_RUNTIME_DIR/all.txt"
mkdir -p "$CODER_DOTFILES_RUNTIME_DIR/new"
printf 'new\n' >"$CODER_DOTFILES_RUNTIME_DIR/new/file.txt"

"$CAPTURE_SCRIPT" >/dev/null
[[ "$(<"$CODER_DOTFILES_SOURCE_DIR/tracked.txt")" == base ]]

"$CAPTURE_SCRIPT" tracked.txt >/dev/null
[[ "$(<"$CODER_DOTFILES_SOURCE_DIR/tracked.txt")" == runtime ]]

git -C "$CODER_DOTFILES_RUNTIME_DIR" restore tracked.txt
"$CAPTURE_SCRIPT" --all >/dev/null
[[ "$(<"$CODER_DOTFILES_SOURCE_DIR/all.txt")" == runtime ]]

"$CAPTURE_SCRIPT" --include-untracked new >/dev/null
[[ "$(<"$CODER_DOTFILES_SOURCE_DIR/new/file.txt")" == new ]]

printf 'source\n' >"$CODER_DOTFILES_SOURCE_DIR/conflict.txt"
if "$CAPTURE_SCRIPT" conflict.txt >/dev/null 2>&1; then
  printf 'FAIL: conflicting source edit was overwritten\n' >&2
  exit 1
fi
[[ "$(<"$CODER_DOTFILES_SOURCE_DIR/conflict.txt")" == source ]]

if "$CAPTURE_SCRIPT" --all --include-untracked >/dev/null 2>&1; then
  printf 'FAIL: unrestricted untracked capture was accepted\n' >&2
  exit 1
fi

printf 'PASS: selective capture works and source conflicts are preserved\n'
