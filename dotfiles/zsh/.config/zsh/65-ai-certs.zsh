# Shared AI CLI certificate wrappers. Mac adds vault-backed CA and secrets.

# Certificate variable is also used by setup.sh.
: ${OMNI_CA_PATH:=/etc/ssl/certs/lan-ca.pem}

# CA resolver. Agent: static lan CA installed at pod provision. Override on mac.
(( $+functions[_omni_ai_ca] )) || _omni_ai_ca() {
  local ca
  for ca in \
    "$OMNI_CA_PATH" \
    "$HOME/.local/share/certs/lan-ca.pem" \
    /usr/local/share/ca-certificates/lan-ca.crt \
    /etc/ssl/certs/lan-ca.pem
  do
    [[ -r $ca ]] && { print -r -- "$ca"; return 0; }
  done
}

# Agent CA is optional; otherwise use the system trust store.
_omni_ai_run() {
  local ca; ca=$(_omni_ai_ca) || :
  [[ -n $ca ]] && export NODE_EXTRA_CA_CERTS="$ca"
  "$@"
}

(( $+functions[codex]  )) || codex()  { ( _omni_ai_run command codex "$@" ) }
(( $+functions[oc]     )) || oc() {
  (
    local key
    key=$("${ENV_DIR:-${ENV_NEXT_DIR:-$HOME/.config/env}}/bin/llm-gateway-token") || return
    LITELLM_API_KEY="$key" _omni_ai_run command opencode "$@"
  )
}
