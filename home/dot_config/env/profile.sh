# POSIX-safe env entrypoint.
# Intended for zsh, bash, sh, agents, editor launchers, and CI-like shells.

ENV_PROFILE_CURRENT_VERSION=12
ENV_DIR="${ENV_DIR:-$HOME/.config/env}"

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
# shellcheck source=functions/audio
if [ -r "$ENV_DIR/functions/audio" ]; then
  . "$ENV_DIR/functions/audio"
fi

# ENV_NEXT_* are the pre-rename names that shells started before the rename still export.
if [ "${ENV_PROFILE_LOADED:-${ENV_NEXT_PROFILE_LOADED:-}}" = 1 ] &&
  [ "${ENV_PROFILE_PATH:-${ENV_NEXT_PROFILE_PATH:-}}" = "${PATH:-}" ] &&
  [ "${ENV_PROFILE_VERSION:-${ENV_NEXT_PROFILE_VERSION:-}}" = "$ENV_PROFILE_CURRENT_VERSION" ]; then
  unset ENV_PROFILE_CURRENT_VERSION
  return 0 2>/dev/null || exit 0
fi
unset ENV_NEXT_PROFILE_LOADED ENV_NEXT_PROFILE_PATH ENV_NEXT_PROFILE_VERSION
# Exported so child shells inherit the guard; bumping the version forces a reload.
export ENV_PROFILE_LOADED=1

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

# shellcheck disable=SC3028
env_os="${ENV_OS:-${ENV_NEXT_OS:-${OSTYPE:-}}}"
case "$env_os" in
  darwin*) env_os="darwin" ;;
  linux*) env_os="linux" ;;
  *)
    env_os="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    case "$env_os" in
      darwin) env_os="darwin" ;;
      linux) env_os="linux" ;;
    esac
    ;;
esac

if [ -r "$ENV_DIR/os/$env_os.sh" ]; then
  # shellcheck source=/dev/null
  . "$ENV_DIR/os/$env_os.sh"
fi

# shellcheck disable=SC3028
env_machine="${ENV_MACHINE:-${ENV_NEXT_MACHINE:-${HOST:-${HOSTNAME:-}}}}"
[ -n "$env_machine" ] || env_machine="$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf unknown)"
env_machine="${env_machine%%.*}"
env_machine="$(printf '%s' "$env_machine" | tr '[:upper:]' '[:lower:]')"
if [ -r "$ENV_DIR/machine/$env_machine.sh" ]; then
  # shellcheck source=/dev/null
  . "$ENV_DIR/machine/$env_machine.sh"
fi

env_path_prepend "$HOME/.cargo/bin"
# mise owns CLIs and runtimes; shims serve shells and agents that never run `mise activate`.
env_path_prepend "${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
env_path_append "$GOPATH/bin"
env_path_append "$ENV_DIR/bin"
env_path_prepend "$HOME/.local/bin"
env_path_prepend "$HOME/.mimocode/bin"

unset env_os env_machine
unset env_rbw_uid_val env_rbw_tmp env_rbw_sock env_rbw_candidate env_rbw_runtime
unset -f env_rbw_uid env_rbw_sock_darwin env_rbw_sock_linux 2>/dev/null || true
unset -f env_path_remove env_path_prepend env_path_append 2>/dev/null || true

export ENV_PROFILE_PATH=$PATH
export ENV_PROFILE_VERSION=$ENV_PROFILE_CURRENT_VERSION
unset ENV_PROFILE_CURRENT_VERSION
