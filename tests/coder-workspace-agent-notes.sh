#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source <(sed -n '/^install_coder_workspace_notes()/,/^}/p' "$repo_dir/setup-coder.sh")

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/.codex" "$tmp_dir/.claude"
printf '# Codex\n' > "$tmp_dir/.codex/AGENTS.md"
printf '# Claude\n' > "$tmp_dir/.claude/CLAUDE.md"

HOME="$tmp_dir" install_coder_workspace_notes

for file in "$tmp_dir/.codex/AGENTS.md" "$tmp_dir/.claude/CLAUDE.md"; do
  grep -Fq 'Docker is available through Docker-in-Docker (DinD).' "$file"
  grep -Fq "Git SSH operations must preserve and use the existing \`\$GIT_SSH_COMMAND\`." "$file"
done

grep -Fxq 'dotfiles/codex/.codex/AGENTS.md' "$repo_dir/scripts/volatile-dots.txt"
grep -Fxq 'dotfiles/claude/.claude/CLAUDE.md' "$repo_dir/scripts/volatile-dots.txt"

printf 'PASS: Coder workspace agent notes are installed locally\n'
