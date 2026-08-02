#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
settings="$repo_dir/dotfiles/omni/.config/omni/settings.json"
groups="$repo_dir/dotfiles/omni/.config/omni/settings.d/groups.json"
dots="$repo_dir/dotfiles/omni/.config/omni/settings.d/dots.json"

jq -e '
  (.hosts.coder | index("ai") != null and index("ai-plugins") != null) and
  (.hosts.hermes | index("ai") == null and index("ai-plugins") == null)
' "$settings" >/dev/null

jq -e '
  any(.groups[]; .name == "hermes" and .special == "host" and .tools == ["camofox-browser", "hermes"]) and
  any(.groups[]; .name == "ai" and
    (.tools | index("claude-code") != null and index("coder") != null and index("@openai/codex") != null))
' "$groups" >/dev/null

jq -e '
  any(.groups[].dots[]?; .name == "tmux" and .hosts.hermes.package == "tmux@hermes") and
  any(.groups[].dots[]?; .name == "bashrc" and .hosts.hermes.package == "bashrc@hermes")
' "$dots" >/dev/null

printf 'PASS: Hermes profile excludes Codex and Claude agent groups\n'
