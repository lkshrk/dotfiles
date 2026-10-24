#!/bin/zsh
set -eu
repo=${1:-${0:A:h:h:h:h:h:h}}
# Do not inherit exporter settings from an already-running agent session.
for name in ${(k)parameters}; do
  case $name in
    OTEL_*|OPENCODE_ENABLE_TELEMETRY|OPENCODE_OTLP_*|OPENCODE_RESOURCE_ATTRIBUTES|CLAUDE_CODE_ENABLE_TELEMETRY|CLAUDE_CODE_ENHANCED_TELEMETRY*) unset "$name" ;;
  esac
done
unset NODE_EXTRA_CA_CERTS
bin=$(mktemp -d)
trap '/bin/rm -rf $bin' EXIT
mkdir -p $bin/norbw $bin/env/bin
print -r -- '#!/bin/sh
[ "$*" = "test prompt" ]' > $bin/norbw/codex
print -r -- '#!/bin/sh
[ "$*" = "test prompt" ] && [ "$LITELLM_API_KEY" = gateway-key ]' > $bin/norbw/opencode
print -r -- '#!/bin/sh
printf "gateway-key\n"' > $bin/env/bin/llm-gateway-token
print -r -- '#!/bin/sh
[ "$*" = "codex -- command codex test prompt" ]' > $bin/env/bin/rbw-env
print -r -- '#!/bin/sh' > $bin/rbw
chmod +x $bin/norbw/* $bin/env/bin/* $bin/rbw
ENV_DIR=$bin/env
expect_ca=/test/lan-ca.pem
check_env() {
  [[ ${NODE_EXTRA_CA_CERTS:-} == $expect_ca ]]
  if env | grep -Eq '^(OTEL_|OPENCODE_(ENABLE_TELEMETRY|OTLP_|RESOURCE_ATTRIBUTES)|CLAUDE_CODE_(ENABLE_TELEMETRY|ENHANCED_TELEMETRY))'; then
    print -u2 'unexpected agent telemetry environment'
    return 1
  fi
}
(
  path=($bin/norbw)
  source "$repo/dotfiles/zsh/.config/zsh/65-ai-certs.zsh"
  source "$repo/dotfiles/zsh/.config/zsh/68-rbw.zsh"
  (( ! $+commands[rbw] && ! $+functions[git] && ! $+functions[sops] ))
  _omni_ai_ca() { return 1; }
  codex 'test prompt'
  oc 'test prompt'
  [[ -z ${NODE_EXTRA_CA_CERTS:-} ]]
)
path=($bin $path)
# The gateway command loaded by profile.sh must survive later zsh modules.
claude() { [[ $* == 'test prompt' ]]; }
source "$repo/dotfiles/zsh/.config/zsh/65-ai-certs.zsh"
source "$repo/dotfiles/zsh/.config/zsh/68-rbw.zsh"
_omni_ai_ca() { print -r -- /test/lan-ca.pem; }
(_omni_ai_run check_env)
codex 'test prompt'
rbw_env() {
  check_env
  local profile=$1
  shift
  case $profile in
    codex) [[ $* == '-- command codex test prompt' ]] ;;
    opencode) [[ $* == '-- command opencode test prompt' ]] ;;
    *) return 1 ;;
  esac
}
export ANTHROPIC_BASE_URL=https://example.invalid ANTHROPIC_AUTH_TOKEN=fake ANTHROPIC_DEFAULT_OPUS_MODEL=fake
claude 'test prompt'
codex 'test prompt'
oc 'test prompt'
[[ $ANTHROPIC_AUTH_TOKEN == fake ]]
_omni_ai_ca() { return 1; }
expect_ca=
claude 'test prompt'
codex 'test prompt'
oc 'test prompt'
print 'agent wrappers: optional CA, secret profiles, arguments, isolation and telemetry checks passed'
