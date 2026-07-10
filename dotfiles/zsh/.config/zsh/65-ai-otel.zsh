# Non-secret OTEL telemetry wrappers for AI CLIs. Shared base (mac + agent).
# Agent uses this as-is: CA from the pod trust store, no secret injection.
# Mac extends it in 70-secrets.zsh / 75-secret-wrappers.zsh by overriding
# _omni_otel_ca (rbw-fetched CA), setting OMNI_OTEL_REQUIRE_CA=1, and the
# wrappers (rbw-env injection).

: ${OMNI_OTEL_ENDPOINT:=https://otel.h-cloud.lan}
: ${OMNI_OTEL_CA_PATH:=/etc/ssl/certs/lan-ca.pem}
: ${OMNI_OTEL_REQUIRE_CA:=0}  # 1 = refuse to launch if the CA is unavailable

# CA resolver. Agent: static lan CA installed at pod provision. Override on mac.
(( $+functions[_omni_otel_ca] )) || _omni_otel_ca() {
  local ca
  for ca in \
    "$OMNI_OTEL_CA_PATH" \
    "$HOME/.local/share/certs/lan-ca.pem" \
    /usr/local/share/ca-certificates/lan-ca.crt \
    /etc/ssl/certs/lan-ca.pem
  do
    [[ -r $ca ]] && { print -r -- "$ca"; return 0; }
  done
}

# Run a command with OTEL env for <service>. CA is optional by default: if
# absent the command still runs (export relies on the system trust store).
# When OMNI_OTEL_REQUIRE_CA=1, a missing CA is fatal so telemetry is never
# silently dropped.
_omni_otel_run() {
  local svc=$1; shift
  local ca; ca=$(_omni_otel_ca)
  if [[ -z $ca && $OMNI_OTEL_REQUIRE_CA == 1 ]]; then
    print -u2 "otel: CA required for $svc but unavailable; not launching"
    return 1
  fi
  # Exported (not prefix-assigned) because a ${ca:+VAR=val} expansion is not
  # recognized as an assignment prefix by zsh and would be run as a command.
  # Callers always invoke this in a subshell, so the export does not leak.
  [[ -n $ca ]] && export NODE_EXTRA_CA_CERTS="$ca"
  [[ -n $ca ]] && export OTEL_EXPORTER_OTLP_CERTIFICATE="$ca"
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
  "$@"
}

(( $+functions[claude] )) || claude() { ( _omni_otel_run claude-code command claude "$@" ) }
(( $+functions[codex]  )) || codex()  { ( _omni_otel_run codex-cli  command codex  "$@" ) }
(( $+functions[oc]     )) || oc()     { ( _omni_otel_run opencode    command opencode "$@" ) }
