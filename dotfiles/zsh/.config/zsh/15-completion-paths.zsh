[[ -d /opt/homebrew/share/zsh/site-functions ]] && fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
[[ -d "$HOME/.docker/completions" ]] && fpath=("$HOME/.docker/completions" $fpath)
[[ -d "$HOME/.cache/zsh/completions" ]] && fpath=("$HOME/.cache/zsh/completions" $fpath)
[[ -d "$HOME/.config/zsh/completions" ]] && fpath=("$HOME/.config/zsh/completions" $fpath)
