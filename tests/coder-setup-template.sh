#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="$repo_dir/dotfiles/codex/.codex/config.toml"

[[ "$(grep -c '^approval_policy[[:space:]]*=' "$config")" == 1 ]]
[[ "$(grep -c '^default_permissions[[:space:]]*=' "$config")" == 1 ]]
[[ "$(grep -c '^[[:space:]]*ca-certificate[[:space:]]*=' "$config")" == 3 ]]
[[ "$(grep -c 'url = "https://api\.ai\.h-cloud\.lan/mcp/"' "$config")" == 1 ]]
if grep -q '^\[mcp_servers\.node_repl' "$config"; then
  exit 1
fi

bash -n \
  "$repo_dir/setup-coder.sh" \
  "$repo_dir/scripts/setup-coder-linux.sh" \
  "$repo_dir/scripts/bootstrap-agents.sh"

printf 'PASS: Coder Codex template supports direct substitutions\n'
