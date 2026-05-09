(( $+functions[with-secrets] )) || return 0

claude() {
  (
    unset ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_BASE_URL API_TIMEOUT_MS ANTHROPIC_AUTH_TOKEN
    CLAUDE_CODE_ENABLE_TELEMETRY=1 \
    OTEL_METRICS_EXPORTER=otlp \
    OTEL_LOGS_EXPORTER=otlp \
    OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf" \
    OTEL_EXPORTER_OTLP_ENDPOINT="https://otel.h-cloud.lan" \
    OTEL_RESOURCE_ATTRIBUTES="cli_tool=claude-code,user=lkshrk" \
    NODE_EXTRA_CA_CERTS="$HOME/.local/share/certs/lan-ca.pem" \
    with-secrets \
      openai-api-key    OPENAI_API_KEY \
      zai-api-key       ZAI_API_KEY \
      hf-token          HF_TOKEN \
      context7-api-key  CONTEXT7_API_KEY \
      -- command claude "$@"
  )
}

codex() {
  (
    OTEL_RESOURCE_ATTRIBUTES="cli_tool=codex-cli,user=lkshrk" \
    with-secrets \
      hf-token          HF_TOKEN \
      context7-api-key  CONTEXT7_API_KEY \
      -- command codex "$@"
  )
}

fcc() {
  (
    with-secrets \
      nvidia-api-key    NVIDIA_NIM_API_KEY \
      openrouter.ai     OPENROUTER_API_KEY \
      context7-api-key  CONTEXT7_API_KEY \
      -- true

    local _fcc_pid=0
    if ! lsof -i :8082 -sTCP:LISTEN &>/dev/null; then
      free-claude-code &>/dev/null &
      _fcc_pid=$!
      local _i=0
      while ! lsof -i :8082 -sTCP:LISTEN &>/dev/null && (( _i++ < 50 )); do
        sleep 0.1
      done
      if ! lsof -i :8082 -sTCP:LISTEN &>/dev/null; then
        print -u2 "fcc: proxy failed to start on :8082"
        return 1
      fi
      print -u2 "fcc: proxy started on :8082 (pid $_fcc_pid)"
    fi

    (( _fcc_pid )) && trap "kill $_fcc_pid 2>/dev/null" EXIT

    ANTHROPIC_BASE_URL="http://localhost:8082" \
    API_TIMEOUT_MS=3000000 \
    command claude "$@"
  )
}

zai() {
  (
    ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air \
    ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5-turbo \
    ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.1 \
    ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic \
    API_TIMEOUT_MS=3000000 \
    with-secrets \
      zai-api-key       ANTHROPIC_AUTH_TOKEN \
      zai-api-key       ZAI_API_KEY \
      context7-api-key  CONTEXT7_API_KEY \
      -- command claude "$@"
  )
}

oc() {
  (
    OPENCODE_ENABLE_TELEMETRY=1 \
    OPENCODE_OTLP_ENDPOINT="https://otel.h-cloud.lan" \
    OPENCODE_OTLP_PROTOCOL="http/protobuf" \
    OPENCODE_RESOURCE_ATTRIBUTES="cli_tool=opencode,user=lkshrk" \
    NODE_EXTRA_CA_CERTS="$HOME/.local/share/certs/lan-ca.pem" \
    with-secrets \
      context7-api-key  CONTEXT7_API_KEY \
      -- command opencode --port "$@"
  )
}

sops() {
  with-secrets \
    h-cloud-age-key   SOPS_AGE_KEY \
    -- command sops "$@"
}

# Lazy-fetch git signing pubkey from rbw item `github` into cache file.
# Pubkey not secret; cache avoids hitting rbw on every signing op.
# Refresh: rm ~/.cache/git-signing-key.pub
_git_signing_key_cache="$HOME/.cache/git-signing-key.pub"

_ensure_git_signing_key() {
  [[ -s $_git_signing_key_cache ]] && return 0
  mkdir -p "${_git_signing_key_cache:h}"
  local val
  val=$(_rbw_get_or_unlock github 2>/dev/null) || {
    print -u2 "git: could not fetch signing pubkey from rbw item 'github'"
    return 1
  }
  print -r -- "$val" > "$_git_signing_key_cache"
}

git() {
  case "$1" in
    commit|tag|merge|rebase|cherry-pick|revert|am|pull)
      _ensure_git_signing_key
      ;;
  esac
  command git "$@"
}
