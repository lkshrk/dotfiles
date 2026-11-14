#!/bin/sh
# Usage: scripts/render-home.sh <host> [dir]   Render the chezmoi source for <host> into dir (default: a new temp dir) and print it.
# Tests use the rendered tree: chezmoi renames files in the source (executable_, dot_, …).
set -eu

host=${1:?usage: render-home.sh <host> [dir]}
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
out=${2:-$(mktemp -d)}
mkdir -p "$out/home"
printf 'sourceDir = "%s"\n[data]\nhost = "%s"\n' "$repo" "$host" > "$out/chezmoi.toml"
chezmoi --config "$out/chezmoi.toml" --source "$repo" --destination "$out/home" \
  --persistent-state "$out/state.boltdb" --no-tty apply --force --exclude=scripts,externals >/dev/null
printf '%s\n' "$out/home"
