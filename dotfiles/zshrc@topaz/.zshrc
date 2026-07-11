# ~/.zshrc — slim loader
# Modular config lives in ~/.config/zsh/*.zsh and is sourced in name order.

# Optional profiler — uncomment top + bottom block to debug startup time
# zmodload zsh/zprof

: "${ENV_DIR:=${ENV_NEXT_DIR:-$HOME/.config/env}}"
[[ -r "$ENV_DIR/profile.sh" ]] && source "$ENV_DIR/profile.sh"

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

if [[ -d "$HOME/.config/zsh" ]]; then
  for _f in "$HOME"/.config/zsh/*.zsh(N); do
    source "$_f"
  done
  unset _f
fi

if [[ "$OSTYPE" == darwin* && -d "$HOME/.config/zsh/macos" ]]; then
  for _f in "$HOME"/.config/zsh/macos/*.zsh(N); do
    source "$_f"
  done
  unset _f
fi

# zprof | head -30

[[ -r "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"



# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
