# ~/.zshrc for Coder workspaces.

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

if [[ -d "$HOME/.config/zsh" ]]; then
  for _f in "$HOME"/.config/zsh/*.zsh(N); do
    source "$_f"
  done
  unset _f
fi
