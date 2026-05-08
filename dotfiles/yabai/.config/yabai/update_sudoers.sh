#!/usr/bin/env bash
# Refresh /etc/sudoers.d/yabai so its `sha256:` entry matches the current
# yabai binary. Idempotent via a user-readable cache of the last-written
# hash at ~/.cache/yabai-sudoers-hash — when the cache matches the binary,
# we skip the sudo call entirely so it doesn't prompt for a password.

set -eu

yabai_path=$(command -v yabai 2>/dev/null || true)
[[ -n "$yabai_path" ]] || { echo "yabai not found in PATH" >&2; exit 1; }

current_hash=$(shasum -a 256 "$yabai_path" | cut -d' ' -f1)
cache="$HOME/.cache/yabai-sudoers-hash"

if [[ -r "$cache" ]] && [[ "$(<"$cache")" == "$current_hash" ]]; then
  exit 0
fi

entry="$(whoami) ALL=(root) NOPASSWD: sha256:${current_hash} ${yabai_path} --load-sa"
echo "$entry" | sudo tee /private/etc/sudoers.d/yabai >/dev/null

mkdir -p "$(dirname "$cache")"
printf '%s\n' "$current_hash" > "$cache"
echo "yabai sudoers entry updated (sha256:${current_hash:0:12}…)"
