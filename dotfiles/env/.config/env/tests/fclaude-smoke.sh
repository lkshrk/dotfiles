#!/bin/sh
set -eu

ENV_PACKAGE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
mkdir -p "$tmpdir/env/bin" "$tmpdir/bin"

cat > "$tmpdir/env/bin/rbw-env" <<'EOF'
#!/bin/sh
[ "$1" = fclaude ] && [ "$2" = -- ]
shift 2
export ANTHROPIC_AUTH_TOKEN=test-key
exec "$@"
EOF

cat > "$tmpdir/bin/claude" <<'EOF'
#!/bin/sh
printf '%s\n' \
  "base=$ANTHROPIC_BASE_URL" \
  "token=$ANTHROPIC_AUTH_TOKEN" \
  "discovery=$CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY" \
  "custom_model=$ANTHROPIC_CUSTOM_MODEL_OPTION" \
  "custom_model_name=$ANTHROPIC_CUSTOM_MODEL_OPTION_NAME" \
  "custom_model_description=$ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION" \
  "args=$*"
EOF
chmod +x "$tmpdir/env/bin/rbw-env" "$tmpdir/bin/claude"

# Regression: functions still load when the expensive profile setup is guarded.
ENV_DIR="$ENV_PACKAGE_DIR"
ENV_NEXT_PROFILE_LOADED=1
ENV_NEXT_PROFILE_PATH=$PATH
ENV_NEXT_PROFILE_VERSION=7
export ENV_DIR ENV_NEXT_PROFILE_LOADED ENV_NEXT_PROFILE_PATH ENV_NEXT_PROFILE_VERSION
# shellcheck source=../profile.sh
. "$ENV_PACKAGE_DIR/profile.sh"
command -v fclaude >/dev/null

output=$(
  ENV_DIR="$tmpdir/env" \
  LITELLM_BASE_URL=https://gateway.example \
  PATH="$tmpdir/bin:/usr/bin:/bin" \
  fclaude --model gateway-model prompt
)

[ "$output" = "base=https://gateway.example
token=test-key
discovery=1
custom_model=free-auto
custom_model_name=Free Auto
custom_model_description=Ordered free-provider failover
args=--model gateway-model prompt" ]
[ -z "${ANTHROPIC_BASE_URL:-}" ]
[ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]
[ -z "${CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY:-}" ]
[ -z "${ANTHROPIC_CUSTOM_MODEL_OPTION:-}" ]
[ -z "${ANTHROPIC_CUSTOM_MODEL_OPTION_NAME:-}" ]
[ -z "${ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION:-}" ]
