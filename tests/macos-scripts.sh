#!/usr/bin/env bash
# The Mac hosts' chezmoi scripts parse under /bin/bash (3.2 on macOS) and avoid bash-4 syntax; their zsh files parse.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

hosts=${MAC_HOSTS:-topaz apm3ljhmvg7xgcf}
[ "$(uname -s)" = Darwin ] && os= || os=',"chezmoi":{"os":"darwin"}'
bash4='\b(mapfile|readarray)\b|\b(declare|local|typeset) -[a-zA-Z]*A|\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?(,,?|\^\^?)\}|\|&|&>>|;;&'

scripts=0
zfiles=0
for h in $hosts; do
  for f in "$repo"/home/.chezmoiscripts/*; do
    out="$tmp/$h-$(basename "$f")"
    chezmoi --source "$repo" --override-data "{\"host\":\"$h\"$os}" execute-template < "$f" > "$out" \
      || fail "host $h: $(basename "$f") does not render"
    grep -q '[^[:space:]]' "$out" || continue
    /bin/bash -n "$out" || fail "host $h: $(basename "$f") fails /bin/bash -n"
    if grep -nE "$bash4" "$out" >&2; then fail "host $h: $(basename "$f") uses bash-4-only syntax"; fi
    scripts=$((scripts + 1))
  done
  if command -v zsh >/dev/null 2>&1; then
    home=$("$repo/scripts/render-home.sh" "$h" "$tmp/render-$h")
    while IFS= read -r z; do
      zsh -n "$z" || fail "host $h: ${z#"$home"/} fails zsh -n"
      zfiles=$((zfiles + 1))
    done < <(find "$home/.config/zsh" -type f \( -name '*.zsh' -o -path '*/completions/*' \); for z in .zshrc .zshenv .zprofile; do [ ! -f "$home/$z" ] || echo "$home/$z"; done)
  fi
done

printf 'PASS: %s, %s scripts parse under %s without bash-4 syntax, %s zsh files parse\n' \
  "$hosts" "$scripts" "$(/bin/bash -c 'echo bash $BASH_VERSION')" "$zfiles"
