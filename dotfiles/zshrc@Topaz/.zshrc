# ~/.zshrc — slim loader
# Modular config lives in ~/.config/zsh/*.zsh and is sourced in name order.
# Local-only overrides (secrets, host-specific) go in 99-local.zsh (gitignored).

# Optional profiler — uncomment top + bottom block to debug startup time
# zmodload zsh/zprof

export ZSH="$HOME/.oh-my-zsh"

if [[ -d "$HOME/.config/zsh" ]]; then
  for _f in "$HOME"/.config/zsh/*.zsh(N); do
    source "$_f"
  done
  unset _f
fi

# zprof | head -30
export PATH=$PATH:$HOME/.maestro/bin
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/lkshrk/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
