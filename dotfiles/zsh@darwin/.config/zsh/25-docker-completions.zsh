[[ -d "$HOME/.docker/completions" ]] || return 0

fpath=("$HOME/.docker/completions" $fpath)
