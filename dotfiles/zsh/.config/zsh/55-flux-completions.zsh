# Wire local Flux shortcuts to Flux's generated completion.
if (( $+functions[compdef] )); then
  if (( $+commands[flux] )); then
    _flux_completion_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/flux-completion.zsh"
    if [[ ! -s "$_flux_completion_cache" || "$commands[flux]" -nt "$_flux_completion_cache" ]]; then
      mkdir -p "${_flux_completion_cache:h}"
      flux completion zsh >| "$_flux_completion_cache" 2>/dev/null
    fi
    [[ -s "$_flux_completion_cache" ]] && source "$_flux_completion_cache"
    unset _flux_completion_cache
  fi

  if (( $+functions[_flux] )); then
    compdef _flux flux
    compdef _flux fx
  fi
fi
