: ${OMNI_CA_PATH:=/etc/ssl/certs/lan-ca.pem}

_omni_ai_ca() {
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

# The LAN CA is optional; without it the system trust store is used.
_omni_ai_run() {
  local ca; ca=$(_omni_ai_ca) || :
  [[ -n $ca ]] && export NODE_EXTRA_CA_CERTS="$ca"
  "$@"
}

codex() {
  if (( $+commands[rbw] && $+functions[rbw_env] )); then
    ( _omni_ai_run rbw_env codex -- codex "$@" )
  else
    ( _omni_ai_run command codex "$@" )
  fi
}
