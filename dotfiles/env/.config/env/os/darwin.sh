# macOS-specific env and PATH facts.

export HOMEBREW_NO_ENV_HINTS="${HOMEBREW_NO_ENV_HINTS:-1}"
export HOMEBREW_REQUIRE_TAP_TRUST="${HOMEBREW_REQUIRE_TAP_TRUST:-1}"

# rbw stores its SSH agent socket under the stable Darwin user temp root.
# Some launchers set TMPDIR to a nested per-process directory, so raw TMPDIR
# would point agents at a socket path that does not exist.
env_next_darwin_uid="${UID:-}"
[ -n "$env_next_darwin_uid" ] || env_next_darwin_uid="$(id -u)"
env_next_darwin_temp_dir="${TMPDIR:-/tmp}"
env_next_rbw_ssh_auth_sock="${env_next_darwin_temp_dir%/}/rbw-$env_next_darwin_uid/ssh-agent-socket"
if [ ! -S "$env_next_rbw_ssh_auth_sock" ]; then
  env_next_darwin_temp_dir="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || printf '%s\n' "${TMPDIR:-/tmp}")"
  env_next_rbw_ssh_auth_sock="${env_next_darwin_temp_dir%/}/rbw-$env_next_darwin_uid/ssh-agent-socket"
fi
if [ -S "$env_next_rbw_ssh_auth_sock" ]; then
  export SSH_AUTH_SOCK="$env_next_rbw_ssh_auth_sock"
else
  case "${SSH_AUTH_SOCK:-}" in
    ''|/var/run/com.apple.launchd.*/Listeners)
      export SSH_AUTH_SOCK="$env_next_rbw_ssh_auth_sock"
      ;;
  esac
fi
unset env_next_rbw_ssh_auth_sock
unset env_next_darwin_temp_dir
unset env_next_darwin_uid

env_next_homebrew_prefix="${HOMEBREW_PREFIX:-}"
if [ -z "$env_next_homebrew_prefix" ]; then
  if [ -d /opt/homebrew/bin ]; then
    env_next_homebrew_prefix=/opt/homebrew
  elif [ -d /usr/local/bin ]; then
    env_next_homebrew_prefix=/usr/local
  fi
fi
if [ -n "$env_next_homebrew_prefix" ] && [ -d "$env_next_homebrew_prefix/bin" ]; then
  export HOMEBREW_PREFIX="$env_next_homebrew_prefix"
  env_next_path_prepend "$env_next_homebrew_prefix/sbin"
  env_next_path_prepend "$env_next_homebrew_prefix/bin"
fi
unset env_next_homebrew_prefix
