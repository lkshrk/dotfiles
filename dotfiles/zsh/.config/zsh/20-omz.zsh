# kubectl completion is loaded lazily in 40-lazy.zsh.
_zsh_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
mkdir -p "$_zsh_cache_dir"
ZSH_COMPDUMP="${ZSH_COMPDUMP:-$_zsh_cache_dir/zcompdump-${${HOST:-${HOSTNAME:-local}}%%.*}-${ZSH_VERSION}}"
unset _zsh_cache_dir

ZSH_THEME="robbyrussell"

plugins=(
  extract
  zsh-autosuggestions
  zsh-syntax-highlighting   # must stay last
)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  autoload -Uz compinit && compinit -d "$ZSH_COMPDUMP"
fi
