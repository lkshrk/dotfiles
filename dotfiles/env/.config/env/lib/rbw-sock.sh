# POSIX-safe rbw SSH-agent socket resolver. Shared by os/*.sh and zsh helpers.
# Callers use command substitution, so the helper-local vars stay in a subshell.

env_next_rbw_uid() {
  if [ -n "${UID:-}" ]; then
    printf '%s\n' "$UID"
  else
    id -u 2>/dev/null || printf '%s\n' ''
  fi
}

# Darwin: canonical socket path under the stable user temp root. Prints the path
# whether or not the socket exists yet — launchd SSH_AUTH_SOCK fixups need it.
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

# Linux: first EXISTING rbw socket among known locations, or empty (rc 1).
env_next_rbw_sock_linux() {
  env_next_rbw_uid_val=$(env_next_rbw_uid)

  if [ -n "${RBW_SSH_AUTH_SOCK:-}" ] && [ -S "$RBW_SSH_AUTH_SOCK" ]; then
    printf '%s\n' "$RBW_SSH_AUTH_SOCK"
    return 0
  fi

  for env_next_rbw_candidate in \
    "${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/rbw/ssh-agent-socket}" \
    "${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/rbw-$env_next_rbw_uid_val/ssh-agent-socket}" \
    "${env_next_rbw_uid_val:+/run/user/$env_next_rbw_uid_val/rbw/ssh-agent-socket}" \
    "${env_next_rbw_uid_val:+/run/user/$env_next_rbw_uid_val/rbw-$env_next_rbw_uid_val/ssh-agent-socket}" \
    "${TMPDIR:-/tmp}/rbw-$env_next_rbw_uid_val/ssh-agent-socket"
  do
    [ -n "$env_next_rbw_candidate" ] || continue
    [ -S "$env_next_rbw_candidate" ] || continue
    printf '%s\n' "$env_next_rbw_candidate"
    return 0
  done

  return 1
}
