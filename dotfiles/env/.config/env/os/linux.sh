# Linux-specific env and PATH facts.

env_next_path_prepend "$HOME/.local/bin"

# pnpm's standalone install refuses `pnpm ls -g` (and aborts omni sync) unless
# its global bin dir is on PATH.
export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
env_next_path_prepend "$PNPM_HOME/bin"

# rbw is optional on Linux. If a socket already exists, adopt it; otherwise
# leave SSH_AUTH_SOCK untouched so ordinary ssh-agent setups keep working.
env_next_linux_sock="$(env_next_rbw_sock_linux || printf '%s\n' '')"
[ -z "$env_next_linux_sock" ] || export SSH_AUTH_SOCK="$env_next_linux_sock"
unset env_next_linux_sock
