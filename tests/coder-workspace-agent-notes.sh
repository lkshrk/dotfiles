#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$repo_dir/setup-coder-components.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/.codex" "$tmp_dir/.claude"
printf '# Codex\n' > "$tmp_dir/.codex/AGENTS.md"
printf '# Claude\n' > "$tmp_dir/.claude/CLAUDE.md"

HOME="$tmp_dir" CODER_ENABLE_DIND=1 install_coder_workspace_notes "$tmp_dir/.codex/AGENTS.md" "$tmp_dir/.claude/CLAUDE.md"
HOME="$tmp_dir" CODER_ENABLE_DIND=1 install_coder_workspace_notes "$tmp_dir/.codex/AGENTS.md" "$tmp_dir/.claude/CLAUDE.md"

for file in "$tmp_dir/.codex/AGENTS.md" "$tmp_dir/.claude/CLAUDE.md"; do
  [[ "$(grep -c '<!-- coder-workspace:start -->' "$file")" == 1 ]]
  grep -Fq 'Docker is available through Docker-in-Docker (DinD).' "$file"
  grep -Fq "Git SSH operations must preserve and use the existing \`\$GIT_SSH_COMMAND\`." "$file"
done

HOME="$tmp_dir" CODER_ENABLE_DIND=0 install_coder_workspace_notes "$tmp_dir/.codex/AGENTS.md" "$tmp_dir/.claude/CLAUDE.md"
for file in "$tmp_dir/.codex/AGENTS.md" "$tmp_dir/.claude/CLAUDE.md"; do
  [[ "$(grep -c '<!-- coder-workspace:start -->' "$file")" == 1 ]]
  ! grep -Fq 'Docker is available' "$file"
  grep -Fq 'Docker-in-Docker (DinD) is not enabled' "$file"
done

grep -Fxq 'dotfiles/codex/.codex/AGENTS.md' "$repo_dir/scripts/volatile-dots.txt"
grep -Fxq 'dotfiles/claude/.claude/CLAUDE.md' "$repo_dir/scripts/volatile-dots.txt"

printf 'PASS: Coder workspace agent notes are installed locally\n'
