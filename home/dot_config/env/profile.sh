# POSIX-safe env entrypoint.
# Intended for zsh, bash, sh, agents, editor launchers, and CI-like shells.

ENV_NEXT_PROFILE_CURRENT_VERSION=10
ENV_DIR="${ENV_DIR:-${ENV_NEXT_DIR:-${HOME}/.config/env}}"

# Functions are cheap to reload and may have been added after the guarded env
# setup ran in this shell.
# shellcheck source=functions/agents
if [ -r "$ENV_DIR/functions/agents" ]; then
  . "$ENV_DIR/functions/agents"
fi
# shellcheck source=functions/hass
if [ -r "$ENV_DIR/functions/hass" ]; then
  . "$ENV_DIR/functions/hass"
fi

if [ "${ENV_NEXT_PROFILE_LOADED:-}" = 1 ] && [ "${ENV_NEXT_PROFILE_PATH:-}" = "${PATH:-}" ] && [ "${ENV_NEXT_PROFILE_VERSION:-}" = "$ENV_NEXT_PROFILE_CURRENT_VERSION" ]; then
  unset ENV_NEXT_PROFILE_CURRENT_VERSION
  return 0 2>/dev/null || exit 0
fi
# Exported so child shells (agent subshell storms) inherit the guard and skip
# the full re-run; PROFILE_VERSION forces a reload when this file is bumped.
export ENV_NEXT_PROFILE_LOADED=1

# shellcheck source=lib/path.sh
if [ -r "$ENV_DIR/lib/path.sh" ]; then
  . "$ENV_DIR/lib/path.sh"
else
  return 0 2>/dev/null || exit 0
fi


# shellcheck source=lib/rbw-sock.sh
if [ -r "$ENV_DIR/lib/rbw-sock.sh" ]; then
  . "$ENV_DIR/lib/rbw-sock.sh"
fi

# shellcheck source=lib/dev-cache.sh
if [ -r "$ENV_DIR/lib/dev-cache.sh" ]; then
  . "$ENV_DIR/lib/dev-cache.sh"
fi

export EDITOR="${EDITOR:-nvim}"
export GOPATH="${GOPATH:-$HOME/go}"
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"

env_next_os="${ENV_NEXT_OS:-${OSTYPE:-}}"
case "$env_next_os" in
  darwin*) env_next_os="darwin" ;;
  linux*) env_next_os="linux" ;;
  *)
    env_next_os="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    case "$env_next_os" in
      darwin) env_next_os="darwin" ;;
      linux) env_next_os="linux" ;;
    esac
    ;;
esac

if [ -r "$ENV_DIR/os/$env_next_os.sh" ]; then
  # shellcheck source=/dev/null
  . "$ENV_DIR/os/$env_next_os.sh"
fi

env_next_machine="${ENV_NEXT_MACHINE:-${HOST:-${HOSTNAME:-}}}"
[ -n "$env_next_machine" ] || env_next_machine="$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf unknown)"
env_next_machine="${env_next_machine%%.*}"
env_next_machine="$(printf '%s' "$env_next_machine" | tr '[:upper:]' '[:lower:]')"
if [ -z "${OMNI_HOSTNAME:-}" ]; then
  export OMNI_HOSTNAME="$env_next_machine"
fi
if [ -r "$ENV_DIR/machine/$env_next_machine.sh" ]; then
  # shellcheck source=/dev/null
  . "$ENV_DIR/machine/$env_next_machine.sh"
fi

env_next_path_prepend "$HOME/.cargo/bin"
env_next_path_prepend "$BUN_INSTALL/bin"
# mise owns CLIs and runtimes; shims serve shells and agents that never run `mise activate`.
env_next_path_prepend "${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
env_next_path_append "$GOPATH/bin"
env_next_path_append "$ENV_DIR/bin"
env_next_path_prepend "$HOME/.local/bin"
env_next_path_prepend "$HOME/.mimocode/bin"

unset env_next_os env_next_machine
unset env_next_rbw_uid_val env_next_rbw_tmp env_next_rbw_sock env_next_rbw_candidate env_next_rbw_runtime
unset -f env_next_rbw_uid env_next_rbw_sock_darwin env_next_rbw_sock_linux 2>/dev/null || true
unset -f env_next_path_remove env_next_path_prepend env_next_path_append 2>/dev/null || true

export ENV_NEXT_PROFILE_PATH=$PATH
export ENV_NEXT_PROFILE_VERSION=$ENV_NEXT_PROFILE_CURRENT_VERSION
unset ENV_NEXT_PROFILE_CURRENT_VERSION
