# POSIX-safe env entrypoint.
# Intended for zsh, bash, sh, agents, editor launchers, and CI-like shells.

if [ "${ENV_NEXT_PROFILE_LOADED:-}" = 1 ] && [ "${ENV_NEXT_PROFILE_PATH:-}" = "${PATH:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
ENV_NEXT_PROFILE_LOADED=1

ENV_DIR="${ENV_DIR:-${ENV_NEXT_DIR:-${HOME}/.config/env}}"

# shellcheck source=lib/path.sh
if [ -r "$ENV_DIR/lib/path.sh" ]; then
  . "$ENV_DIR/lib/path.sh"
else
  return 0 2>/dev/null || exit 0
fi

# shellcheck source=lib/nvm-node.sh
if [ -r "$ENV_DIR/lib/nvm-node.sh" ]; then
  . "$ENV_DIR/lib/nvm-node.sh"
fi

export EDITOR="${EDITOR:-nvim}"
export GOPATH="${GOPATH:-$HOME/go}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL:-$HOME/.config/git/config}"

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
if [ -r "$ENV_DIR/machine/$env_next_machine.sh" ]; then
  # shellcheck source=/dev/null
  . "$ENV_DIR/machine/$env_next_machine.sh"
fi

unset PNPM_HOME
env_next_homebrew_prefix="${HOMEBREW_PREFIX:-}"
env_next_homebrew_openjdk=
if [ -n "$env_next_homebrew_prefix" ]; then
  env_next_homebrew_openjdk="$env_next_homebrew_prefix/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
fi
if [ -n "$env_next_homebrew_openjdk" ] && [ "${JAVA_HOME:-}" = "$env_next_homebrew_openjdk" ]; then
  unset JAVA_HOME
fi
env_next_path_remove "$HOME/Library/pnpm"
env_next_path_remove "$HOME/Library/pnpm/bin"
env_next_path_remove "$HOME/.local/share/pnpm"
[ -z "$env_next_homebrew_openjdk" ] || env_next_path_remove "$env_next_homebrew_openjdk/bin"

env_next_nvm_bin=
if command -v env_next_nvm_resolve_bin >/dev/null 2>&1; then
  env_next_nvm_bin=$(env_next_nvm_resolve_bin default 2>/dev/null || true)
fi
[ -z "$env_next_nvm_bin" ] || env_next_path_prepend "$env_next_nvm_bin"

env_next_path_prepend "$BUN_INSTALL/bin"
env_next_path_append "$GOPATH/bin"
env_next_path_prepend "$HOME/.local/bin"
env_next_path_prepend "$HOME/.mimocode/bin"

unset env_next_os env_next_machine env_next_nvm_bin
unset env_next_homebrew_prefix env_next_homebrew_openjdk
unset env_next_nvm_lookup env_next_nvm_root env_next_nvm_i env_next_nvm_line
unset env_next_nvm_pattern env_next_nvm_best env_next_nvm_best_major env_next_nvm_best_minor
unset env_next_nvm_best_patch env_next_nvm_candidate env_next_nvm_name env_next_nvm_version
unset env_next_nvm_major env_next_nvm_rest env_next_nvm_minor env_next_nvm_patch
unset env_next_nvm_target env_next_nvm_dir
unset -f env_next_nvm_alias_target env_next_nvm_best_dir_for_pattern 2>/dev/null || true
unset -f env_next_nvm_resolve_dir env_next_nvm_resolve_bin 2>/dev/null || true
unset -f env_next_path_remove env_next_path_prepend env_next_path_append 2>/dev/null || true

ENV_NEXT_PROFILE_PATH=$PATH
