# Lazy Homebrew OpenJDK link. Homebrew installs Java outside macOS' java_home
# registry unless linked globally; keep shell startup light and avoid sudo symlinks.
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

java()   { unset -f java javac jar javadoc keytool 2>/dev/null; _load_homebrew_openjdk || return; command java "$@"; }
javac()  { unset -f java javac jar javadoc keytool 2>/dev/null; _load_homebrew_openjdk || return; command javac "$@"; }
jar()    { unset -f java javac jar javadoc keytool 2>/dev/null; _load_homebrew_openjdk || return; command jar "$@"; }
javadoc(){ unset -f java javac jar javadoc keytool 2>/dev/null; _load_homebrew_openjdk || return; command javadoc "$@"; }
keytool(){ unset -f java javac jar javadoc keytool 2>/dev/null; _load_homebrew_openjdk || return; command keytool "$@"; }

if [[ -n "${GHOSTTY_RESOURCES_DIR:-}" && -r "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration" ]]; then
  source "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"
fi

return 0
