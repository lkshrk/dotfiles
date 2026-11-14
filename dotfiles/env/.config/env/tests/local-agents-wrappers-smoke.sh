#!/bin/sh
set -eu

ENV_PACKAGE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO_DIR=$(CDPATH= cd -- "$ENV_PACKAGE_DIR/../../../.." && pwd)
unset LITELLM_API_KEY
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
mkdir -p "$tmpdir/env/bin" "$tmpdir/bin"

cat > "$tmpdir/env/bin/local-agents-token" <<'EOF'
#!/bin/sh
printf '%s\n' test-key
EOF
cat > "$tmpdir/bin/agent" <<'EOF'
#!/bin/sh
printf '%s\n' "key=${LITELLM_API_KEY:-}" "args=$*"
EOF
chmod +x "$tmpdir/env/bin/local-agents-token" "$tmpdir/bin/agent"

expected='key=test-key
args=run -m local-agents/gpt-astra two words'

for wrapper in omp-local-agents:OMP_BIN opencode-local-agents:OPENCODE_BIN; do
  script=${wrapper%%:*}
  bin_var=${wrapper#*:}
  output=$(env ENV_DIR="$tmpdir/env" "$bin_var=$tmpdir/bin/agent" \
    "$ENV_PACKAGE_DIR/bin/$script" run -m local-agents/gpt-astra 'two words')
  [ "$output" = "$expected" ] || { printf '%s: unexpected output\n%s\n' "$script" "$output" >&2; exit 1; }
done

cat > "$tmpdir/env/bin/rbw-env" <<'EOF'
#!/bin/sh
[ "$*" = "--pairs gh-cli GITHUB_PERSONAL_ACCESS_TOKEN -- ${0%/env/bin/rbw-env}/bin/gh-agent" ] || exit 9
shift 4
GITHUB_PERSONAL_ACCESS_TOKEN=gh-test exec "$@"
EOF
printf '#!/bin/sh\n' > "$tmpdir/bin/rbw"
printf '#!/bin/sh\nprintf "gh=%%s\\n" "${GITHUB_PERSONAL_ACCESS_TOKEN:-}"\n' > "$tmpdir/bin/gh-agent"
chmod +x "$tmpdir/env/bin/rbw-env" "$tmpdir/bin/rbw" "$tmpdir/bin/gh-agent"
for wrapper in omp-local-agents:OMP_BIN opencode-local-agents:OPENCODE_BIN; do
  script=${wrapper%%:*}
  bin_var=${wrapper#*:}
  output=$(env -u GITHUB_PERSONAL_ACCESS_TOKEN PATH="$tmpdir/bin:$PATH" ENV_DIR="$tmpdir/env" \
    "$bin_var=$tmpdir/bin/gh-agent" "$ENV_PACKAGE_DIR/bin/$script")
  [ "$output" = gh=gh-test ] || { printf '%s: GitHub token not injected: %s\n' "$script" "$output" >&2; exit 1; }
done
rm "$tmpdir/env/bin/rbw-env" "$tmpdir/bin/rbw"

cat > "$tmpdir/env/bin/local-agents-token" <<'EOF'
#!/bin/sh
exit 1
EOF
if env ENV_DIR="$tmpdir/env" OPENCODE_BIN="$tmpdir/bin/agent" \
  "$ENV_PACKAGE_DIR/bin/opencode-local-agents" >/dev/null 2>&1; then
  printf '%s\n' 'opencode-local-agents: launched without a credential' >&2
  exit 1
fi

# oc must resolve opencode through PATH so it reaches the wrapper.
ln -s "$tmpdir/bin/agent" "$tmpdir/bin/opencode"
oc_output=$(
  PATH="$tmpdir/bin:$PATH" LITELLM_API_KEY=from-path
  export PATH LITELLM_API_KEY
  # shellcheck source=../functions/opencode
  . "$ENV_PACKAGE_DIR/functions/opencode"
  oc --version
)
[ "$oc_output" = 'key=from-path
args=--version' ]

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
const [provider, model] = c.model.split("#")[0].split("/");
if (provider !== "local-agents" || !p.models[model]) fail(`default model ${c.model} is not declared`);
const title = c.agents.title.model.split("/")[1];
if (!p.models[title]) fail(`title model ${title} is not declared`);
for (const [id, m] of Object.entries(p.models)) {
  const want = id.startsWith("claude-") ? "@opencode/ai/providers/anthropic"
    : id.startsWith("gpt-") ? "@opencode/ai/providers/openai/responses" : undefined;
  if (m.package !== want) fail(`${id} uses ${m.package ?? "the provider default"}`);
}
if ("mcp" in c && Object.keys(c.mcp.servers).some((n) => n !== "litellm-tools")) fail("only litellm-tools belongs here; APM owns other MCP servers");
EOF
fi
if grep -Eq 'sk-[A-Za-z0-9]{8,}' "$config"; then
  printf '%s\n' 'opencode.jsonc: contains a literal key' >&2
  exit 1
fi

printf '%s\n' 'omp, opencode and oc: credential and GitHub token injection, arguments, failure and config checks passed'
