#!/usr/bin/env bash
# Every brew/cask entry in the Mac hosts' Brewfiles resolves with `brew info` (taps them first). Needs brew and network.
set -euo pipefail
export LC_ALL=C

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
command -v brew >/dev/null 2>&1 || { echo 'SKIP: brew is not installed'; exit 0; }
hosts=${MAC_HOSTS:-topaz apm3ljhmvg7xgcf}
# Private or retired formulae and casks that are expected not to resolve.
allowed_missing=" xcodebuildmcp flux-markdown depflush sbx "

files=$(for h in $hosts; do
  for g in $(sed -n "s/^  $h: \[\(.*\)\]$/\1/p" "$repo/home/.chezmoidata/hosts.yaml" | tr -d ' ' | tr ',' ' '); do
    [ ! -f "$repo/packages/brew/$g.Brewfile" ] || echo "$repo/packages/brew/$g.Brewfile"
  done
done | sort -u)
[ -n "$files" ] || { echo 'FAIL: no Brewfiles for the Mac hosts' >&2; exit 1; }
# shellcheck disable=SC2086
entries=$(cat $files | sort -u)

for tap in $(printf '%s\n' "$entries" | sed -n 's/^tap "\(.*\)"$/\1/p'); do
  out=$(brew tap "$tap" 2>&1) || echo "WARN: tap $tap failed: $(printf '%s\n' "$out" | tail -1)"
  ! brew trust --help >/dev/null 2>&1 || brew trust "$tap" >/dev/null 2>&1 || echo "WARN: trust $tap failed"
done

missing='' allowed=''
for kind in brew cask; do
  names=$(printf '%s\n' "$entries" | sed -n "s/^$kind \"\(.*\)\"$/\1/p")
  [ -n "$names" ] || continue
  flag=--formula; [ "$kind" = cask ] && flag=--cask
  # shellcheck disable=SC2086
  brew info --json=v2 $flag $names >/dev/null 2>&1 && continue
  for n in $names; do
    err=$(brew info --json=v2 "$flag" "$n" 2>&1 >/dev/null) && continue
    case $allowed_missing in
      *" ${n##*/} "*) allowed="$allowed $kind:$n" ;;
      *) missing="$missing $kind:$n"; printf '  %s: %s\n' "$n" "$(printf '%s\n' "$err" | grep -m1 . || true)" >&2 ;;
    esac
  done
done

[ -z "$allowed" ] || echo "allowed missing:$allowed"
[ -z "$missing" ] || { echo "FAIL: Brewfile entries that do not resolve:$missing" >&2; exit 1; }
printf 'PASS: %s Brewfile entries resolve for %s\n' "$(printf '%s\n' "$entries" | grep -cE '^(brew|cask) ')" "$hosts"
