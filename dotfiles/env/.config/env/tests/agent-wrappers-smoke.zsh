#!/bin/zsh
set -eu
repo=${1:-${0:A:h:h:h:h:h:h}}
# Do not inherit exporter settings from an already-running agent session.
for name in ${(k)parameters}; do
  case $name in
    OTEL_*|OPENCODE_ENABLE_TELEMETRY|OPENCODE_OTLP_*|OPENCODE_RESOURCE_ATTRIBUTES|CLAUDE_CODE_ENABLE_TELEMETRY|CLAUDE_CODE_ENHANCED_TELEMETRY*) unset "$name" ;;
  esac
done
source "$repo/dotfiles/zsh/.config/zsh/65-ai-otel.zsh"
_root_ca_cert_file() { print -r -- /test/lan-ca.pem; }
_omni_ai_ca() { _root_ca_cert_file; }
check_env() {
  [[ $NODE_EXTRA_CA_CERTS == /test/lan-ca.pem ]]
  if env | grep -Eq '^(OTEL_|OPENCODE_(ENABLE_TELEMETRY|OTLP_|RESOURCE_ATTRIBUTES)|CLAUDE_CODE_(ENABLE_TELEMETRY|ENHANCED_TELEMETRY))'; then
    print -u2 'unexpected agent telemetry environment'
    return 1
  fi
}
(_omni_ai_run check_env)
(_omni_ai_ca() { return 1; }; _omni_ai_run true)
source "$repo/dotfiles/zsh/.config/zsh/macos/75-secret-wrappers.zsh"
_rbw_env() {
  check_env
  local profile=$1
  shift
  case $profile in
    claude)
      [[ $* == '-- command claude test prompt' ]]
      [[ -z ${ANTHROPIC_BASE_URL:-} && -z ${ANTHROPIC_AUTH_TOKEN:-} ]]
      [[ -z ${ANTHROPIC_DEFAULT_OPUS_MODEL:-} ]]
      ;;
    codex) [[ $* == '-- command codex test prompt' ]] ;;
    opencode) [[ $* == '-- command opencode --port test prompt' ]] ;;
    *) return 1 ;;
  esac
}
export ANTHROPIC_BASE_URL=https://example.invalid ANTHROPIC_AUTH_TOKEN=fake ANTHROPIC_DEFAULT_OPUS_MODEL=fake
claude 'test prompt'
codex 'test prompt'
oc 'test prompt'
[[ $ANTHROPIC_AUTH_TOKEN == fake ]]
_root_ca_cert_file() { return 1; }
if claude test || codex test || oc test; then
  print -u2 'wrapper ignored missing required CA'
  exit 1
fi
print 'agent wrappers: CA, secret profiles, arguments, isolation and telemetry checks passed'
