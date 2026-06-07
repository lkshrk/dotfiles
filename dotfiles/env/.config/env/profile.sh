# POSIX-safe env entrypoint.
# Intended for zsh, bash, sh, agents, editor launchers, and CI-like shells.

ENV_DIR="${ENV_DIR:-${ENV_NEXT_DIR:-${HOME}/.config/env}}"

# shellcheck source=lib/path.sh
if [ -r "$ENV_DIR/lib/path.sh" ]; then
  . "$ENV_DIR/lib/path.sh"
else
  return 0 2>/dev/null || exit 0
fi

export EDITOR="${EDITOR:-nvim}"
export GOPATH="${GOPATH:-$HOME/go}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL:-$HOME/.config/git/config}"

env_next_os="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
case "$env_next_os" in
  darwin) env_next_os="darwin" ;;
  linux) env_next_os="linux" ;;
esac

if [ -r "$ENV_DIR/os/$env_next_os.sh" ]; then
  # shellcheck source=/dev/null
  . "$ENV_DIR/os/$env_next_os.sh"
fi

env_next_machine="$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf unknown)"
env_next_machine="$(printf '%s\n' "$env_next_machine" | tr '[:upper:]' '[:lower:]')"
if [ -r "$ENV_DIR/machine/$env_next_machine.sh" ]; then
  # shellcheck source=/dev/null
  . "$ENV_DIR/machine/$env_next_machine.sh"
fi

env_next_path_prepend "$BUN_INSTALL/bin"
env_next_path_append "$GOPATH/bin"
env_next_path_prepend "$HOME/.local/bin"

unset env_next_os env_next_machine
unset -f env_next_path_remove env_next_path_prepend env_next_path_append 2>/dev/null || true
