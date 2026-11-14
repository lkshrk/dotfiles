#!/usr/bin/env bash
# Static checks for packages/: known groups, sorted unique lists, no duplicates, valid Brewfile lines, declared taps.
set -euo pipefail
export LC_ALL=C

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repo/packages"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

groups=$(sed -n 's/^  [^:]*: \[\(.*\)\]$/\1/p' "$repo/home/.chezmoidata/hosts.yaml" | tr ',' '\n' | tr -d ' ' | sort -u)
for f in arch/* brew/*; do
  g=$(basename "$f"); g=${g%%.*}
  printf '%s\n' "$groups" | grep -qx "$g" || fail "$f: group '$g' is not in hosts.yaml"
done

for f in arch/*; do
  sort -uc "$f" 2>/dev/null || fail "$f: not sorted or has duplicates"
  ! grep -qE '[[:space:]]|^$' "$f" || fail "$f: blank lines or spaces"
done
dupes=$(cat arch/* | sort | uniq -d)
[ -z "$dupes" ] || fail "in more than one Arch list: $(echo $dupes)"
for f in installer/*.txt; do
  [ -f "$f" ] || continue
  sort -uc "$f" 2>/dev/null || fail "$f: not sorted or has duplicates"
  both=$(cat arch/* | sort -u | comm -12 - "$f")
  [ -z "$both" ] || fail "$f: the installer owns these; keep them out of the role lists: $(echo $both)"
done
if ls /usr/share/omarchy/install/*.packages >/dev/null 2>&1; then
  omarchy=$(cat /usr/share/omarchy/install/*.packages | sed 's/#.*//' | tr -s ' \t' '\n' | grep -v '^$' | sort -u)
  shipped=$(cat arch/* | sort -u | comm -12 - <(printf '%s\n' "$omarchy"))
  [ -z "$shipped" ] || fail "Omarchy ships these; keep them out of our lists: $(echo $shipped)"
fi

for f in brew/*.Brewfile; do
  ! grep -vqE '^(tap|brew|cask) "[^"]+"$' "$f" || fail "$f: line that is not tap/brew/cask \"name\""
  for name in $(sed -n 's/^\(brew\|cask\) "\([^"]*\/[^"]*\)\/[^"/]*"$/\2/p' "$f"); do
    grep -qx "tap \"$name\"" "$f" || fail "$f: tap \"$name\" is used but not declared"
  done
done
dupes=$(grep -hE '^(brew|cask) ' brew/*.Brewfile | sort | uniq -d)
[ -z "$dupes" ] || fail "in more than one Brewfile: $(echo $dupes)"

printf '%s\n' "PASS: package lists name known groups, are sorted and unique, skip Omarchy defaults, declare their taps"
