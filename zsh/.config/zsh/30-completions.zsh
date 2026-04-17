# compinit once, with a daily-rebuilt cached dump.
# Add anything to fpath BEFORE compinit runs.

fpath=("$HOME/.docker/completions" $fpath)

autoload -Uz compinit

_zcd="$HOME/.cache/zsh/zcompdump"
mkdir -p "${_zcd:h}"

# Rebuild dump if older than 24h, otherwise use -C (skip security check + glob)
if [[ -n "$_zcd"(#qN.mh+24) ]] || [[ ! -s "$_zcd" ]]; then
  compinit -d "$_zcd"
else
  compinit -C -d "$_zcd"
fi

unset _zcd
