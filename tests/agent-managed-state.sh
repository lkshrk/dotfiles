#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/.." && pwd)
agents_json="$repo_dir/dotfiles/omni/.config/omni/settings.d/agents.json"
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

if rg -q \
  'agents-skill-lock|plugins/installed_plugins\.json|!dotfiles/claude/\.claude/plugins/|claude/\.claude/(mcp\.json|skills/)|!/mcp\.json' \
  "$repo_dir/.gitignore" \
  "$repo_dir/scripts/volatile-dots.txt" \
  "$repo_dir/setup-coder.sh"; then
  fail "legacy agent-state sync reference remains"
fi

for source in \
  mattpocock/skills \
  vercel-labs/skills \
  lkshrk/linear-ai \
  rjyo/moshi-skill \
  lkshrk/useful-skills \
  ShiplightAI/agent-skills-v2 \
  ShiplightAI/agent-skills \
  sopaco/deepwiki-rs; do
  jq -e --arg source "$source" \
    '[.agents.packages[].source] | index($source) != null' \
    "$agents_json" >/dev/null || fail "legacy skill source lacks Omni declaration: $source"
done

jq -e '
  [.agents.plugins[] | .name + "@" + .marketplace] | index("caveman@caveman") != null
' "$agents_json" >/dev/null || fail "Caveman legacy skill lacks its Omni-managed plugin"

for identity in \
  academic-research-skills@academic-research-skills \
  caveman@caveman \
  claude-md-management@claude-plugins-official \
  code-simplifier@claude-plugins-official \
  codex@openai-codex \
  context-mode@context-mode \
  ecc@ecc \
  frontend-design@claude-plugins-official \
  github@claude-plugins-official \
  gopls-lsp@claude-plugins-official \
  lua-lsp@claude-plugins-official \
  superpowers@claude-plugins-official \
  swift-lsp@claude-plugins-official; do
  jq -e --arg identity "$identity" '
    ($identity | split("@")[0]) as $name
    | ([.agents.plugins[] | .name + "@" + .marketplace] | index($identity) != null)
      or ([.agents.ignore.plugins[]] | index($name) != null)
  ' "$agents_json" >/dev/null || fail "legacy plugin lacks Omni declaration or ignore: $identity"
done

jq -e '
  (.agents.mcp_servers | length > 0)
  and ([.agents.packages[].source] | index("JuliusBrussee/caveman") == null)
  and ([.agents.marketplaces[]
    | select(.name == "context-mode")
    | .agents[]] | index("codex") != null)
  and ([.agents.marketplaces[]
    | select(.name == "context-mode")
    | .agents[]] | index("claude-code") != null)
  and ([.agents.plugins[]
    | select(.name == "context-mode" and .marketplace == "context-mode")
    | .agents[]] | index("codex") != null)
  and ([.agents.plugins[]
    | select(.name == "context-mode" and .marketplace == "context-mode")
    | .agents[]] | index("claude-code") != null)
' "$agents_json" >/dev/null || fail "Omni manifest replacement is incomplete"

if [[ ${OMNI_VERIFY_LIVE_AGENT_STATE:-0} == 1 ]]; then
  live_inventory="${CLAUDE_CONFIG_DIR:-${HOME:?}/.claude}/plugins/installed_plugins.json"
  [[ -f "$live_inventory" && ! -L "$live_inventory" ]] ||
    fail "live Claude plugin inventory was removed or replaced: $live_inventory"
fi

printf 'PASS: agent-managed state is owned by Omni\n'
