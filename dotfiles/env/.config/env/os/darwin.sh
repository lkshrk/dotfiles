# macOS-specific env and PATH facts.

export HOMEBREW_NO_ENV_HINTS="${HOMEBREW_NO_ENV_HINTS:-1}"
export HOMEBREW_REQUIRE_TAP_TRUST="${HOMEBREW_REQUIRE_TAP_TRUST:-1}"
export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home}"

# rbw stores its SSH agent socket under the stable Darwin user temp root.
# Some launchers set TMPDIR to a nested per-process directory, so raw TMPDIR
# would point agents at a socket path that does not exist.
env_next_darwin_temp_dir="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || printf '%s\n' "${TMPDIR:-/tmp}")"
export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-${env_next_darwin_temp_dir%/}/rbw-$(id -u)/ssh-agent-socket}"
unset env_next_darwin_temp_dir

if [ -d /opt/homebrew/bin ]; then
  env_next_path_prepend /opt/homebrew/sbin
  env_next_path_prepend /opt/homebrew/bin
fi

if [ -n "${JAVA_HOME:-}" ]; then
  env_next_path_prepend "$JAVA_HOME/bin"
fi

env_next_path_prepend "$PNPM_HOME"
