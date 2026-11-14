(( $+commands[direnv] )) || return 0

# The hook embeds direnv's absolute path, which is versioned under mise; resolve it through PATH instead.
eval "$(direnv hook zsh | sed -E "s#\\\$'[^']*/direnv'#direnv#g")"
