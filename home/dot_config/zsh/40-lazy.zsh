_kc_cache="$HOME/.cache/zsh/kubectl-completion.zsh"
if (( $+commands[kubectl] )); then
  if [[ ! -s "$_kc_cache" || "$commands[kubectl]" -nt "$_kc_cache" ]]; then
    mkdir -p "${_kc_cache:h}"
    kubectl completion zsh > "$_kc_cache" 2>/dev/null
  fi
  source "$_kc_cache"
fi
unset _kc_cache

