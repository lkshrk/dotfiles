(( $+functions[_root_ca_cert_file] )) || return 0

builtin unalias codex oc 2>/dev/null || :

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
    _rbw_env opencode -- command opencode "$@"
  )
}
