# macOS-specific env and PATH facts.

export HOMEBREW_NO_ENV_HINTS="${HOMEBREW_NO_ENV_HINTS:-1}"
export HOMEBREW_REQUIRE_TAP_TRUST="${HOMEBREW_REQUIRE_TAP_TRUST:-1}"
export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home}"

# rbw stores its SSH agent socket under the stable Darwin user temp root.
# Some launchers set TMPDIR to a nested per-process directory, so raw TMPDIR
# would point agents at a socket path that does not exist.
env_next_darwin_temp_dir="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || printf '%s\n' "${TMPDIR:-/tmp}")"
env_next_rbw_ssh_auth_sock="${env_next_darwin_temp_dir%/}/rbw-$(id -u)/ssh-agent-socket"
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

if [ -d /opt/homebrew/bin ]; then
  env_next_path_prepend /opt/homebrew/sbin
  env_next_path_prepend /opt/homebrew/bin
fi

if [ -n "${JAVA_HOME:-}" ]; then
  env_next_path_prepend "$JAVA_HOME/bin"
fi

env_next_path_prepend "$PNPM_HOME"
