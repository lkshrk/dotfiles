nvm() {
  unset -f nvm node npm npx 2>/dev/null
  [[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]] && source "/opt/homebrew/opt/nvm/nvm.sh"
  nvm "$@"
}
node() { unset -f nvm node npm npx 2>/dev/null
        [[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]] && source "/opt/homebrew/opt/nvm/nvm.sh"
        node "$@"; }
npm()  { unset -f nvm node npm npx 2>/dev/null
        [[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]] && source "/opt/homebrew/opt/nvm/nvm.sh"
        npm "$@"; }
npx()  { unset -f nvm node npm npx 2>/dev/null
        [[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]] && source "/opt/homebrew/opt/nvm/nvm.sh"
        npx "$@"; }

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
