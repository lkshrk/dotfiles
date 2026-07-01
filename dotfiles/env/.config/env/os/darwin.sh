# macOS-specific env and PATH facts.

export HOMEBREW_NO_ENV_HINTS="${HOMEBREW_NO_ENV_HINTS:-1}"
export HOMEBREW_REQUIRE_TAP_TRUST="${HOMEBREW_REQUIRE_TAP_TRUST:-1}"

# rbw's SSH agent socket lives under the stable Darwin user temp root; the
# resolver in lib/rbw-sock.sh handles the nested-TMPDIR fixup.
env_next_darwin_sock="$(env_next_rbw_sock_darwin)"
if [ -S "$env_next_darwin_sock" ]; then
  export SSH_AUTH_SOCK="$env_next_darwin_sock"
else
  case "${SSH_AUTH_SOCK:-}" in
    ''|/var/run/com.apple.launchd.*/Listeners)
      export SSH_AUTH_SOCK="$env_next_darwin_sock"
      ;;
  esac
fi
unset env_next_darwin_sock

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
