#!/bin/sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../../../../.." && pwd)
config="$REPO_DIR/dotfiles/opencode/.config/opencode/opencode.jsonc"
if command -v node >/dev/null 2>&1; then
  node - "$config" <<'EOF'
const fs = require("fs");
const text = fs.readFileSync(process.argv[2], "utf8");
const json = text.replace(/("(?:[^"\\]|\\.)*")|\/\/[^\n]*/g, (m, s) => s ?? "");
const c = JSON.parse(json);
const p = c.providers["local-agents"];
const fail = (m) => { console.error(`opencode.jsonc: ${m}`); process.exit(1); };
if (p.settings.apiKey !== "{env:LITELLM_API_KEY}") fail("provider key must come from LITELLM_API_KEY");
if (c.mcp.servers["litellm-tools"].headers["x-litellm-api-key"] !== "{env:LITELLM_API_KEY}") fail("MCP key must come from LITELLM_API_KEY");
const [provider, ...rest] = c.model.split("#")[0].split("/");
const model = rest.join("/");
if (provider !== "local-agents" || !p.models[model]) fail(`default model ${c.model} is not declared`);
const title = c.agents.title.model.split("/").slice(1).join("/");
if (!p.models[title]) fail(`title model ${title} is not declared`);
for (const [id, m] of Object.entries(p.models)) {
  const base = id.split("/").pop();
  const want = base.startsWith("claude-") ? "@opencode/ai/providers/anthropic"
    : base.startsWith("gpt-") ? "@opencode/ai/providers/openai/responses" : undefined;
  if (m.package !== want) fail(`${id} uses ${m.package ?? "the provider default"}`);
}
if ("mcp" in c && Object.keys(c.mcp.servers).some((n) => n !== "litellm-tools")) fail("only litellm-tools belongs here; APM owns other MCP servers");
EOF
fi
if grep -Eq 'sk-[A-Za-z0-9]{8,}' "$config"; then
  printf '%s\n' 'opencode.jsonc: contains a literal key' >&2
  exit 1
fi

printf '%s\n' 'opencode.jsonc: provider, model and MCP checks passed'
