#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/.." && pwd)
dots_json="$repo_dir/dotfiles/omni/.config/omni/settings.d/dots.json"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for path in \
  "$repo_dir/dotfiles/agents-skill-lock/.agents/.skill-lock.json" \
  "$repo_dir/dotfiles/claude/.claude/plugins/installed_plugins.json"; do
  [[ ! -e "$path" ]] || fail "tracked agent runtime state remains: ${path#"$repo_dir/"}"
done

for tracked in \
  dotfiles/agents-skill-lock/.agents/.skill-lock.json \
  dotfiles/claude/.claude/plugins/installed_plugins.json; do
  if git -C "$repo_dir" ls-files --error-unmatch "$tracked" >/dev/null 2>&1; then
    ! git -C "$repo_dir" diff --quiet -- "$tracked" ||
      fail "agent runtime state is still tracked without a pending deletion: $tracked"
  fi
done

jq -e '
  all(.groups[].dots[]?;
    .name != "agents-skill-lock"
    and .path != "~/.agents/.skill-lock.json"
    and (.ignore | index("!/mcp.json") | not)
    and (.ignore | index("!/plugins") | not)
    and (.ignore | index("!/plugins/installed_plugins.json") | not)
    and (.ignore | index("!/skills/") | not)
  )
' "$dots_json" >/dev/null || fail "dots manifest still allows agent-managed state"

if grep -Eq \
  'agents-skill-lock|plugins/installed_plugins\.json|!dotfiles/claude/\.claude/plugins/|claude/\.claude/(mcp\.json|skills/)|!/mcp\.json' \
  "$repo_dir/.gitignore" \
  "$repo_dir/scripts/volatile-dots.txt" \
  "$repo_dir/setup-coder-components.sh"; then
  fail "legacy agent-state sync reference remains"
fi

if [[ ${OMNI_VERIFY_LIVE_AGENT_STATE:-0} == 1 ]]; then
  live_inventory="${CLAUDE_CONFIG_DIR:-${HOME:?}/.claude}/plugins/installed_plugins.json"
  [[ -f "$live_inventory" && ! -L "$live_inventory" ]] ||
    fail "live Claude plugin inventory was removed or replaced: $live_inventory"
fi

printf 'PASS: live agent-managed state is excluded from dotfile synchronization\n'
