#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
settings="$repo_dir/dotfiles/omni/.config/omni/settings.json"
groups="$repo_dir/dotfiles/omni/.config/omni/settings.d/groups.json"
dots="$repo_dir/dotfiles/omni/.config/omni/settings.d/dots.json"

jq -e '
  .host_settings."auto-code".dots_repo == "~/dotfiles" and
  (.hosts."auto-code" | index("core") != null and index("shell") != null)
' "$settings" >/dev/null

jq -e '
  any(.groups[]; .name == "auto-code" and .special == "host" and .tools == [])
' "$groups" >/dev/null

jq -e '
  any(.groups[]; .name == "auto-code" and
    any(.dots[]; .name == "ssh" and .path == "~/.ssh/config"))
' "$dots" >/dev/null

printf 'PASS: auto-code host uses generic workspace dots plus SSH\n'
