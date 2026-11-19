env_path_prepend "$HOME/.local/bin"

# Standalone pnpm refuses `pnpm ls -g` unless its bin dir is on PATH.
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
env_path_prepend "$PNPM_HOME/bin"

# Node ignores the system trust store, so LAN hosts need the CA named explicitly.
if [ -z "${NODE_EXTRA_CA_CERTS:-}" ] && [ -r "$HOME/.local/share/certs/lan-ca.pem" ]; then
  export NODE_EXTRA_CA_CERTS="$HOME/.local/share/certs/lan-ca.pem"
fi

# Adopt a running vault agent; otherwise keep SSH_AUTH_SOCK for ordinary ssh-agent setups.
env_linux_sock="$(env_agent_sock_linux)" || :
if [ -n "$env_linux_sock" ]; then
  export SSH_AUTH_SOCK="$env_linux_sock"
elif [ -z "${SSH_AUTH_SOCK:-}" ]; then
  # The desktop session starts before the agent does, and GUI apps never re-read the environment.
  env_linux_sock="$(env_agent_sock_linux_planned)" || :
  [ -z "$env_linux_sock" ] || export SSH_AUTH_SOCK="$env_linux_sock"
fi
unset env_linux_sock
