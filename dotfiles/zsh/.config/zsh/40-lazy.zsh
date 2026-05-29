_load_nvm() {
  unset -f nvm node 2>/dev/null
  [[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]] && source "/opt/homebrew/opt/nvm/nvm.sh"
}

nvm() {
  _load_nvm
  nvm "$@"
}
node() { _load_nvm; command node "$@"; }
npm()  { bun "$@"; }
npx()  { command bunx "$@"; }

_kc_cache="$HOME/.cache/zsh/kubectl-completion.zsh"
if (( $+commands[kubectl] )); then
  if [[ ! -s "$_kc_cache" || "$commands[kubectl]" -nt "$_kc_cache" ]]; then
    mkdir -p "${_kc_cache:h}"
    kubectl completion zsh > "$_kc_cache" 2>/dev/null
  fi
  source "$_kc_cache"
fi
unset _kc_cache

bun() {
  unset -f bun
  [[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
  bun "$@"
}

[[ -n "${GHOSTTY_RESOURCES_DIR}" ]] \
  && source "${GHOSTTY_RESOURCES_DIR}/shell-integration/zsh/ghostty-integration"

# Lazy Homebrew OpenJDK link. Homebrew installs Java outside macOS' java_home
# registry unless linked globally; keep shell startup light and avoid sudo symlinks.
_load_homebrew_openjdk() {
  local _java_home="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
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
