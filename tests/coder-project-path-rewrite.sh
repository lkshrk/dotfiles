#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source <(sed -n '/^rewrite_coder_project_paths()/,/^}/p' "$repo_dir/setup-coder.sh")

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
config="$tmp_dir/config.toml"
cat > "$config" <<'EOF'
[projects."/Users/lkshrk/Dev/routivo"]
trust_level = "trusted"

[projects."/Users/lkshrk"]
trust_level = "trusted"

[hooks.state."/Users/lkshrk/Dev/omni/.codex/hooks.json:pre_tool_use:0:0"]
trusted_hash = "sha256:test"
EOF

HOME=/home/coder rewrite_coder_project_paths "$config"

grep -Fq '[projects."/home/coder/routivo"]' "$config"
grep -Fq '[projects."/Users/lkshrk"]' "$config"
grep -Fq '[hooks.state."/Users/lkshrk/Dev/omni/.codex/hooks.json:pre_tool_use:0:0"]' "$config"

printf 'PASS: Coder project trust paths use the workspace home\n'
