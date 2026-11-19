# The vault's SSH agent: the Bitwarden desktop app's on Linux, rbw's on macOS. Callers use command substitution.

env_agent_uid() {
  if [ -n "${UID:-}" ]; then
    printf '%s\n' "$UID"
  else
    id -u 2>/dev/null || printf '%s\n' ''
  fi
}

# Prints the path even before the socket exists; launchd SSH_AUTH_SOCK fixups need it.
env_agent_sock_darwin() {
  env_agent_uid_val=$(env_agent_uid)
  env_agent_tmp="${TMPDIR:-/tmp}"
  env_agent_sock="${env_agent_tmp%/}/rbw-$env_agent_uid_val/ssh-agent-socket"
  if [ ! -S "$env_agent_sock" ]; then
    env_agent_tmp="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || printf '%s\n' "${TMPDIR:-/tmp}")"
    env_agent_sock="${env_agent_tmp%/}/rbw-$env_agent_uid_val/ssh-agent-socket"
  fi
  printf '%s\n' "$env_agent_sock"
}

# A running agent's socket: VAULT_SSH_AUTH_SOCK, the desktop app's, or an rbw agent's.
env_agent_sock_linux() {
  env_agent_uid_val=$(env_agent_uid)

  if [ -n "${VAULT_SSH_AUTH_SOCK:-}" ] && [ -S "$VAULT_SSH_AUTH_SOCK" ]; then
    printf '%s\n' "$VAULT_SSH_AUTH_SOCK"
    return 0
  fi

  env_agent_runtime="${XDG_RUNTIME_DIR:-/run/user/$env_agent_uid_val}"
  for env_agent_candidate in \
    "$HOME/.bitwarden-ssh-agent.sock" \
    "$env_agent_runtime/rbw/ssh-agent-socket" \
    "$env_agent_runtime/rbw-$env_agent_uid_val/ssh-agent-socket" \
    "${TMPDIR:-/tmp}/rbw-$env_agent_uid_val/ssh-agent-socket"
  do
    [ -S "$env_agent_candidate" ] || continue
    printf '%s\n' "$env_agent_candidate"
    return 0
  done

  return 1
}

# Where the agent will listen once it starts, for sessions that begin before it.
env_agent_sock_linux_planned() {
  if [ -x /usr/bin/bitwarden ] || [ -d /opt/Bitwarden ]; then
    printf '%s\n' "$HOME/.bitwarden-ssh-agent.sock"
  elif [ -n "${XDG_RUNTIME_DIR:-}" ] && command -v rbw >/dev/null 2>&1; then
    printf '%s\n' "$XDG_RUNTIME_DIR/rbw/ssh-agent-socket"
  else
    return 1
  fi
}
