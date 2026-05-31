# Non-secret OTEL telemetry wrappers for AI CLIs. Shared base (mac + agent).
# Agent uses this as-is: CA from the pod trust store, no secret injection.
# Mac extends it in 70-secrets.zsh / 75-secret-wrappers.zsh by overriding
# _omni_otel_ca (rbw-fetched CA) and the wrappers (with-secrets injection).

: ${OMNI_OTEL_ENDPOINT:=https://otel.h-cloud.lan}
: ${OMNI_OTEL_CA_PATH:=/etc/ssl/certs/lan-ca.pem}

# CA resolver. Agent: static lan CA installed at pod provision. Override on mac.
_omni_otel_ca() { [[ -r $OMNI_OTEL_CA_PATH ]] && print -r -- "$OMNI_OTEL_CA_PATH" }

# Run a command with OTEL env for <service>. CA is optional: if absent the
# command still runs (telemetry export just relies on the system trust store).
_omni_otel_run() {
  local svc=$1; shift
  local ca; ca=$(_omni_otel_ca)
  CLAUDE_CODE_ENABLE_TELEMETRY=1 \
  CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1 \
  OTEL_METRICS_EXPORTER=otlp \
  OTEL_LOGS_EXPORTER=otlp \
  OTEL_TRACES_EXPORTER=otlp \
  OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf" \
  OTEL_EXPORTER_OTLP_ENDPOINT="$OMNI_OTEL_ENDPOINT" \
  OTEL_EXPORTER_OTLP_METRICS_ENDPOINT="$OMNI_OTEL_ENDPOINT/v1/metrics" \
  OTEL_EXPORTER_OTLP_LOGS_ENDPOINT="$OMNI_OTEL_ENDPOINT/v1/logs" \
  OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="$OMNI_OTEL_ENDPOINT/v1/traces" \
  OTEL_SERVICE_NAME="$svc" \
  OTEL_RESOURCE_ATTRIBUTES="cli_tool=$svc,user=${USER}" \
  ${ca:+NODE_EXTRA_CA_CERTS="$ca"} \
  "$@"
}

claude() { ( _omni_otel_run claude-code command claude "$@" ) }
codex()  { ( _omni_otel_run codex-cli  command codex  "$@" ) }
oc()     { ( _omni_otel_run opencode    command opencode "$@" ) }
