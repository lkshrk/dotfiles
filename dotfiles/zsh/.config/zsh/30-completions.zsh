autoload -Uz compinit

_zcd="$HOME/.cache/zsh/zcompdump"
_zcd_paths="$HOME/.cache/zsh/zcompdump.fpath"
mkdir -p "${_zcd:h}"

_current_fpath="${(j.:.)fpath}"
if [[ -n "$_zcd"(#qN.mh+24) || ! -s "$_zcd" || ! -s "$_zcd_paths" ]] || \
   [[ "$(<"$_zcd_paths")" != "$_current_fpath" ]]; then
  compinit -d "$_zcd"
  print -r -- "$_current_fpath" >| "$_zcd_paths"
else
  compinit -C -d "$_zcd"
fi

unset _zcd _zcd_paths _current_fpath
