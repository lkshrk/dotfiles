# Homebrew's OpenJDK sits outside java_home unless linked with sudo, so it is put on PATH at first use.
_load_homebrew_openjdk() {
  local _homebrew_prefix="${HOMEBREW_PREFIX:-}"
  [[ -n "$_homebrew_prefix" ]] || return 127
  local _java_home="$_homebrew_prefix/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
  [[ -x "$_java_home/bin/java" ]] || return 127
  if [[ -z "${JAVA_HOME:-}" || ! -x "$JAVA_HOME/bin/java" ]]; then
    export JAVA_HOME="$_java_home"
  fi
  case ":$PATH:" in
    *":$JAVA_HOME/bin:"*) ;;
    *) export PATH="$JAVA_HOME/bin:$PATH" ;;
  esac
}

for _tool in java javac jar javadoc keytool; do
  eval "$_tool() { unset -f java javac jar javadoc keytool 2>/dev/null; _load_homebrew_openjdk || return; command $_tool \"\$@\"; }"
done
unset _tool

if [[ -n "${GHOSTTY_RESOURCES_DIR:-}" && -r "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration" ]]; then
  source "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
fi

return 0
