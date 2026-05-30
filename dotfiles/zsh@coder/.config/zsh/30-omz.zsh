ZSH_THEME="${ZSH_THEME:-robbyrussell}"

plugins=(
  git
  docker
  kubectl
  extract
  zsh-autosuggestions
  zsh-syntax-highlighting
)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

autoload -Uz compinit
_zcd="$HOME/.cache/zsh/zcompdump"
mkdir -p "${_zcd:h}"

if [[ -n "$_zcd"(#qN.mh+24) ]] || [[ ! -s "$_zcd" ]]; then
  compinit -d "$_zcd"
else
  compinit -C -d "$_zcd"
fi

unset _zcd
