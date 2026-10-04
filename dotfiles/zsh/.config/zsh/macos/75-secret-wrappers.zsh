_rbw_env() {
  local wrapper="${ENV_DIR:-${ENV_NEXT_DIR:-$HOME/.config/env}}/bin/rbw-env"
  if [[ -x "$wrapper" ]]; then
    "$wrapper" "$@"
  else
    print -u2 "rbw-env: wrapper unavailable"
    return 127
  fi
}

(( $+functions[_root_ca_cert_file] )) || return 0

builtin unalias codex oc sops 2>/dev/null || :

codex() {
  (
    local ca
    ca=$(_root_ca_cert_file) || return
    NODE_EXTRA_CA_CERTS="$ca" \
    _rbw_env codex -- command codex "$@"
  )
}

oc() {
  (
    local ca
    ca=$(_root_ca_cert_file) || return
    NODE_EXTRA_CA_CERTS="$ca" \
    _rbw_env opencode -- command opencode --port "$@"
  )
}

sops() {
  _rbw_env sops -- command sops "$@"
}
