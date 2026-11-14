#!/bin/sh
set -eu

ENV_PACKAGE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY \
  LITELLM_API LITELLM_API_KEY LITELLM_BASE_URL GITHUB_PERSONAL_ACCESS_TOKEN HF_TOKEN NODE_EXTRA_CA_CERTS \
  OMNI_CA_PATH CLAUDE_BIN CODEX_BIN OMP_BIN OPENCODE_BIN
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
mkdir -p "$tmpdir/env/bin" "$tmpdir/bin" "$tmpdir/rbw" "$tmpdir/shim" "$tmpdir/sys"
# A PATH without the real rbw, so no test can read the vault.
for tool in sh sed readlink tr cat uname dirname env; do
  ln -s "$(command -v "$tool")" "$tmpdir/sys/$tool"
done
env_dir=$tmpdir/env

ln -s "$ENV_PACKAGE_DIR/bin/agent-run" "$env_dir/bin/agent-run"
ln -s "$ENV_PACKAGE_DIR/bin/rbw-env" "$env_dir/bin/rbw-env"
ln -s "$ENV_PACKAGE_DIR/secrets" "$env_dir/secrets"
printf '#!/bin/sh\nprintf "%%s\\n" token-file\n' > "$env_dir/bin/local-agents-token"
cat > "$tmpdir/rbw/rbw" <<'EOF'
#!/bin/sh
case $1 in
  unlocked) exit 0 ;;
  get) for a; do :; done; printf 'secret-%s\n' "$a" ;;
  *) exit 1 ;;
esac
EOF
cat > "$tmpdir/bin/agent" <<'EOF'
#!/bin/sh
printf '%s\n' "name=${0##*/}" "base=${ANTHROPIC_BASE_URL:-}" "token=${ANTHROPIC_AUTH_TOKEN:-}" \
  "discovery=${CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY:-}" "litellm=${LITELLM_API:-}" \
  "litellm_key=${LITELLM_API_KEY:-}" "github=${GITHUB_PERSONAL_ACCESS_TOKEN:-}" "hf=${HF_TOKEN:-}" \
  "ca=${NODE_EXTRA_CA_CERTS:-}" "args=$*"
EOF
chmod +x "$env_dir/bin/local-agents-token" "$tmpdir/rbw/rbw" "$tmpdir/bin/agent"
for name in claude codex omp opencode; do
  ln -s agent "$tmpdir/bin/$name"
done
ln -s "$env_dir/bin/agent-run" "$tmpdir/shim/omp"
ln -s "$env_dir/bin/agent-run" "$tmpdir/shim/opencode"

ENV_DIR=$env_dir
OMNI_CA_PATH=/nonexistent
export ENV_DIR OMNI_CA_PATH
with_rbw="$tmpdir/shim:$tmpdir/rbw:$tmpdir/bin:$tmpdir/sys"
without_rbw="$tmpdir/shim:$tmpdir/bin:$tmpdir/sys"
# shellcheck source=../functions/agents
. "$ENV_PACKAGE_DIR/functions/agents"

fail() {
  printf 'agent-run: %s\n' "$1" >&2
  exit 1
}
field() { printf '%s\n' "$1" | sed -n "s/^$2=//p"; }
expect() {
  [ "$(field "$1" "$2")" = "$3" ] || fail "$4: unexpected $2"
}

out=$(PATH=$with_rbw claude --model m 'two words')
expect "$out" name claude claude
expect "$out" base https://api.ai.h-cloud.lan claude
expect "$out" token secret-local-agents claude
expect "$out" discovery 1 claude
expect "$out" github secret-gh-cli claude
expect "$out" litellm_key secret-local-agents claude
expect "$out" args '--model m two words' claude
[ -z "${ANTHROPIC_BASE_URL:-}${ANTHROPIC_AUTH_TOKEN:-}" ] || fail 'claude leaked into the caller'
out=$(PATH=$with_rbw LITELLM_BASE_URL=https://gateway.example claude)
expect "$out" base https://gateway.example 'claude base override'

out=$(PATH=$with_rbw ANTHROPIC_AUTH_TOKEN=leak LITELLM_API=leak claude_hass)
expect "$out" token secret-hass-agent claude-hass
expect "$out" litellm secret-hass-agent claude-hass

out=$(PATH=$with_rbw ANTHROPIC_BASE_URL=https://leak.example ANTHROPIC_AUTH_TOKEN=leak ccs prompt)
expect "$out" base '' claude-sub
expect "$out" token '' claude-sub
expect "$out" litellm secret-local-agents claude-sub
expect "$out" args prompt claude-sub

out=$(PATH=$with_rbw codex exec x)
expect "$out" name codex codex
expect "$out" litellm secret-local-agents codex
expect "$out" github secret-gh-cli codex
expect "$out" hf secret-hf-token codex

out=$(PATH=$with_rbw omp run 'a b')
expect "$out" name omp omp
expect "$out" litellm_key secret-local-agents omp
expect "$out" github secret-gh-cli omp
expect "$out" args 'run a b' omp
out=$(PATH=$with_rbw oc --version)
expect "$out" name opencode oc
expect "$out" litellm_key secret-local-agents oc

out=$(PATH=$without_rbw omp)
expect "$out" litellm_key token-file 'omp without rbw'
expect "$out" github '' 'omp without rbw'
out=$(PATH=$without_rbw claude)
expect "$out" token token-file 'claude without rbw'

printf '#!/bin/sh\nexit 1\n' > "$env_dir/bin/local-agents-token"
if PATH=$without_rbw omp >/dev/null 2>&1; then fail 'omp launched without a gateway key'; fi
out=$(PATH=$without_rbw codex)
expect "$out" litellm '' 'codex without any key'

: > "$tmpdir/ca.pem"
out=$(PATH=$with_rbw OMNI_CA_PATH="$tmpdir/ca.pem" codex)
expect "$out" ca "$tmpdir/ca.pem" 'LAN CA'
out=$(PATH=$with_rbw NODE_EXTRA_CA_CERTS=/inherited.pem OMNI_CA_PATH="$tmpdir/ca.pem" codex)
expect "$out" ca /inherited.pem 'inherited CA'

out=$(PATH=$with_rbw OMP_BIN="$tmpdir/bin/codex" omp)
expect "$out" name codex 'OMP_BIN override'
rm "$tmpdir/bin/omp"
set +e
PATH=$with_rbw omp >/dev/null 2>&1
status=$?
set -e
[ "$status" = 127 ] || fail "missing omp binary exited $status, want 127"

printf '%s\n' 'agent-run: profiles, gateway fallback, isolation, CA, binary lookup and argument checks passed'
