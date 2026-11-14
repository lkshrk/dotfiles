export HOMEBREW_NO_ENV_HINTS="${HOMEBREW_NO_ENV_HINTS:-1}"
export HOMEBREW_REQUIRE_TAP_TRUST="${HOMEBREW_REQUIRE_TAP_TRUST:-1}"

export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
env_path_prepend "$PNPM_HOME/bin"

env_darwin_sock="$(env_rbw_sock_darwin)"
if [ -S "$env_darwin_sock" ]; then
  export SSH_AUTH_SOCK="$env_darwin_sock"
else
  case "${SSH_AUTH_SOCK:-}" in
    ''|/var/run/com.apple.launchd.*/Listeners)
      export SSH_AUTH_SOCK="$env_darwin_sock"
      ;;
  esac
fi
unset env_darwin_sock

env_homebrew_prefix="${HOMEBREW_PREFIX:-}"
if [ -z "$env_homebrew_prefix" ]; then
  if [ -d /opt/homebrew/bin ]; then
    env_homebrew_prefix=/opt/homebrew
  elif [ -d /usr/local/bin ]; then
    env_homebrew_prefix=/usr/local
  fi
fi
if [ -n "$env_homebrew_prefix" ] && [ -d "$env_homebrew_prefix/bin" ]; then
  export HOMEBREW_PREFIX="$env_homebrew_prefix"
  env_path_prepend "$env_homebrew_prefix/sbin"
  env_path_prepend "$env_homebrew_prefix/bin"
fi
unset env_homebrew_prefix

[ ! -d "$HOME/.docker/bin" ] || env_path_append "$HOME/.docker/bin"
