#!/bin/zsh
set -eu
repo=${1:-${0:A:h:h:h:h:h:h}}
# Do not inherit exporter settings from an already-running agent session.
for name in ${(k)parameters}; do
  case $name in
    OTEL_*|CLAUDE_CODE_ENABLE_TELEMETRY|CLAUDE_CODE_ENHANCED_TELEMETRY*) unset "$name" ;;
  esac
done
unset NODE_EXTRA_CA_CERTS
bin=$(mktemp -d)
trap '/bin/rm -rf $bin' EXIT
mkdir -p $bin/norbw $bin/env/bin
print -r -- '#!/bin/sh
[ "$*" = "test prompt" ]' > $bin/norbw/codex
print -r -- '#!/bin/sh
printf "gateway-key\n"' > $bin/env/bin/local-agents-token
ln -s "$repo/dotfiles/env/.config/env/bin/rbw-env" $bin/env/bin/rbw-env
ln -s "$repo/dotfiles/env/.config/env/secrets" $bin/env/secrets
print -r -- '#!/bin/sh
[ "$1" = get ] || exit 0
for a; do :; done
printf "secret-%s\n" "$a"' > $bin/rbw
print -r -- '#!/bin/sh
[ "$*" = "test prompt" ] && [ "$LITELLM_API" = secret-litellm-api ] && [ "${NODE_EXTRA_CA_CERTS:-}" = "$EXPECT_CA" ]' > $bin/codex
chmod +x $bin/norbw/* $bin/env/bin/local-agents-token $bin/rbw $bin/codex
ENV_DIR=$bin/env
unset HF_TOKEN LITELLM_API CONTEXT7_API_KEY LITELLM_API_KEY
expect_ca=/test/lan-ca.pem
check_env() {
  [[ ${NODE_EXTRA_CA_CERTS:-} == $expect_ca ]]
  if env | grep -Eq '^(OTEL_|CLAUDE_CODE_(ENABLE_TELEMETRY|ENHANCED_TELEMETRY))'; then
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
  [[ -z ${NODE_EXTRA_CA_CERTS:-} ]]
)
path=($bin $path)
# The gateway command loaded by profile.sh must survive later zsh modules.
claude() { [[ $* == 'test prompt' ]]; }
source "$repo/dotfiles/zsh/.config/zsh/65-ai-certs.zsh"
source "$repo/dotfiles/zsh/.config/zsh/68-rbw.zsh"
_omni_ai_ca() { print -r -- /test/lan-ca.pem; }
export EXPECT_CA=$expect_ca
(_omni_ai_run check_env)
export ANTHROPIC_BASE_URL=https://example.invalid ANTHROPIC_AUTH_TOKEN=fake ANTHROPIC_DEFAULT_OPUS_MODEL=fake
claude 'test prompt'
codex 'test prompt'
[[ $ANTHROPIC_AUTH_TOKEN == fake ]]
_omni_ai_ca() { return 1; }
expect_ca= EXPECT_CA=
claude 'test prompt'
codex 'test prompt'
print 'agent wrappers: optional CA, secret profiles, arguments, isolation and telemetry checks passed'
