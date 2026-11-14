#!/usr/bin/env bash
# Renders every host's tree and chezmoi scripts, on Linux and with the OS forced to darwin, and lints the scripts.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

hosts=$(sed -n '/^hosts:/,$ s/^  \([A-Za-z0-9_.-][A-Za-z0-9_.-]*\):.*/\1/p' "$repo/home/.chezmoidata/hosts.yaml")
[ -n "$hosts" ] || fail "no hosts found in hosts.yaml"
have_shellcheck=0
command -v shellcheck >/dev/null 2>&1 && have_shellcheck=1

count=0
for h in $hosts; do
  "$repo/scripts/render-home.sh" "$h" "$tmp/render-$h" >/dev/null 2>"$tmp/err" || { cat "$tmp/err" >&2; fail "render-home.sh failed for host $h"; }
  for os in linux darwin; do
    data="{\"host\":\"$h\",\"chezmoi\":{\"os\":\"$os\"}}"
    for f in "$repo"/home/.chezmoiscripts/*; do
      name=$(basename "$f")
      out="$tmp/out.sh"
      chezmoi --source "$repo" --override-data "$data" execute-template < "$f" > "$out" 2>"$tmp/err" \
        || { cat "$tmp/err" >&2; fail "host $h ($os): $name does not render"; }
      [ -s "$out" ] && grep -q '[^[:space:]]' "$out" || continue
      bash -n "$out" 2>"$tmp/err" || { cat "$tmp/err" >&2; fail "host $h ($os): $name fails bash -n"; }
      if [ "$have_shellcheck" = 1 ]; then
        shellcheck -S warning -s bash "$out" >"$tmp/err" 2>&1 || { cat "$tmp/err" >&2; fail "host $h ($os): $name fails shellcheck"; }
      fi
      count=$((count + 1))
    done
  done
done

printf 'PASS: %s hosts, %s rendered scripts checked (bash -n%s)\n' "$(echo "$hosts" | wc -w)" "$count" "$([ "$have_shellcheck" = 1 ] && echo ', shellcheck')"
