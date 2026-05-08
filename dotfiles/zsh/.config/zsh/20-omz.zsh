# kubectl completion is loaded lazily in 40-lazy.zsh.
ZSH_THEME="robbyrussell"

plugins=(
  extract
  zsh-autosuggestions
  zsh-syntax-highlighting   # must stay last
)

source "$ZSH/oh-my-zsh.sh"
