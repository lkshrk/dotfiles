_rbw_env() {
  local wrapper="${ENV_NEXT_DIR:-$HOME/Dev/dotfiles/dotfiles/env-next}/bin/rbw-env"
  if [[ -x "$wrapper" ]]; then
    "$wrapper" "$@"
  else
    print -u2 "rbw-env: wrapper unavailable"
    return 127
  fi
}

(( $+functions[_root_ca_cert_file] )) || return 0

builtin unalias claude codex oc sops 2>/dev/null || :

_ensure_omni_otel_run() {
  (( $+functions[_omni_otel_run] )) && return 0
  source "$HOME/.config/zsh/65-ai-otel.zsh" 2>/dev/null || return 1
  (( $+functions[_omni_otel_run] ))
}

claude() {
  (
    unset ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_BASE_URL API_TIMEOUT_MS ANTHROPIC_AUTH_TOKEN
    local -a cmd
    cmd=(_rbw_env claude -- command claude "$@")
    if _ensure_omni_otel_run; then
      _omni_otel_run claude-code "${cmd[@]}"
    else
      print -u2 "otel: _omni_otel_run unavailable; launching claude without telemetry"
      "${cmd[@]}"
    fi
  )
}

codex() {
  (
    local _otel_ca
    _otel_ca=$(_root_ca_cert_file) || return
    NODE_EXTRA_CA_CERTS="$_otel_ca" \
    OTEL_SERVICE_NAME="codex-cli" \
    OTEL_RESOURCE_ATTRIBUTES="cli_tool=codex-cli,user=lkshrk" \
    _rbw_env codex -- command codex "$@"
  )
}

oc() {
  (
    local _otel_ca
    _otel_ca=$(_root_ca_cert_file) || return
    OPENCODE_ENABLE_TELEMETRY=1 \
    OPENCODE_OTLP_PROTOCOL="http/protobuf" \
    OPENCODE_OTLP_ENDPOINT="https://otel.h-cloud.lan" \
    OPENCODE_OTLP_METRICS_INTERVAL=1000 \
    OPENCODE_OTLP_LOGS_INTERVAL=1000 \
    OPENCODE_RESOURCE_ATTRIBUTES="service.name=opencode,cli_tool=opencode,user=lkshrk" \
    OTEL_BSP_SCHEDULE_DELAY=1000 \
    OTEL_BLRP_SCHEDULE_DELAY=1000 \
    OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf" \
    OTEL_EXPORTER_OTLP_ENDPOINT="https://otel.h-cloud.lan" \
    OTEL_EXPORTER_OTLP_LOGS_ENDPOINT="https://otel.h-cloud.lan/v1/logs" \
    OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="https://otel.h-cloud.lan/v1/traces" \
    OTEL_SERVICE_NAME="opencode" \
    OTEL_RESOURCE_ATTRIBUTES="cli_tool=opencode,user=lkshrk" \
    NODE_EXTRA_CA_CERTS="$_otel_ca" \
    _rbw_env opencode -- command opencode --port "$@"
  )
}

sops() {
  _rbw_env sops -- command sops "$@"
}
