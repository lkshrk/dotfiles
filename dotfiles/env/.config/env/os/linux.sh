# Linux-specific env and PATH facts.

env_next_path_prepend "$HOME/.local/bin"

# Standalone pnpm refuses `pnpm ls -g` (aborting omni sync) unless its bin dir is on PATH.
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
env_next_path_prepend "$PNPM_HOME/bin"

# Node and Bun ignore the system trust store, so LAN hosts need the CA named explicitly.
if [ -z "${NODE_EXTRA_CA_CERTS:-}" ] && [ -r "$HOME/.local/share/certs/lan-ca.pem" ]; then
  export NODE_EXTRA_CA_CERTS="$HOME/.local/share/certs/lan-ca.pem"
fi

# Adopt an existing rbw socket; otherwise keep SSH_AUTH_SOCK for ordinary ssh-agent setups.
env_next_linux_sock="$(env_next_rbw_sock_linux)" || :
[ -z "$env_next_linux_sock" ] || export SSH_AUTH_SOCK="$env_next_linux_sock"
unset env_next_linux_sock
