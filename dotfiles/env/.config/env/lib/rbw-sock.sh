# Callers use command substitution, so the helper globals stay in a subshell.

env_next_rbw_uid() {
  if [ -n "${UID:-}" ]; then
    printf '%s\n' "$UID"
  else
    id -u 2>/dev/null || printf '%s\n' ''
  fi
}

# Prints the path even before the socket exists; launchd SSH_AUTH_SOCK fixups need it.
env_next_rbw_sock_darwin() {
  env_next_rbw_uid_val=$(env_next_rbw_uid)
  env_next_rbw_tmp="${TMPDIR:-/tmp}"
  env_next_rbw_sock="${env_next_rbw_tmp%/}/rbw-$env_next_rbw_uid_val/ssh-agent-socket"
  if [ ! -S "$env_next_rbw_sock" ]; then
    env_next_rbw_tmp="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || printf '%s\n' "${TMPDIR:-/tmp}")"
    env_next_rbw_sock="${env_next_rbw_tmp%/}/rbw-$env_next_rbw_uid_val/ssh-agent-socket"
  fi
  printf '%s\n' "$env_next_rbw_sock"
}

env_next_rbw_sock_linux() {
  env_next_rbw_uid_val=$(env_next_rbw_uid)

  if [ -n "${RBW_SSH_AUTH_SOCK:-}" ] && [ -S "$RBW_SSH_AUTH_SOCK" ]; then
    printf '%s\n' "$RBW_SSH_AUTH_SOCK"
    return 0
  fi

  env_next_rbw_runtime="${XDG_RUNTIME_DIR:-/run/user/$env_next_rbw_uid_val}"
  for env_next_rbw_candidate in \
    "$env_next_rbw_runtime/rbw/ssh-agent-socket" \
    "$env_next_rbw_runtime/rbw-$env_next_rbw_uid_val/ssh-agent-socket" \
    "${TMPDIR:-/tmp}/rbw-$env_next_rbw_uid_val/ssh-agent-socket"
  do
    [ -S "$env_next_rbw_candidate" ] || continue
    printf '%s\n' "$env_next_rbw_candidate"
    return 0
  done

  return 1
}
