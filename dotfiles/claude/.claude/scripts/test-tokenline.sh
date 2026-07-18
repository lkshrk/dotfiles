#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
repo_dir=$(git -C "$script_dir" rev-parse --show-toplevel)
tokenline_bash=$(command -v bash)
[ ! -x /opt/homebrew/bin/bash ] || tokenline_bash=/opt/homebrew/bin/bash

output=$(
  TOKENLINE_COLUMNS=100 "$tokenline_bash" "$script_dir/tokenline.sh" <<JSON
{
  "model": {"display_name": "Opus"},
  "workspace": {
    "current_dir": "$repo_dir",
    "repo": {"name": "dotfiles"},
    "git_worktree": "review"
  },
  "worktree": {"branch": "feature/statusline"},
  "context_window": {
    "used_percentage": 25,
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 0,
      "output_tokens": 0,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 0
    }
  },
  "session_id": "tokenline-test"
}
JSON
)

first_line=${output%%$'\n'*}
plain=$(printf '%s' "$first_line" | sed $'s/\033\\[[0-9;]*m//g')

case "$plain" in
  *"dotfiles [feature/statusline/review]") ;;
  *)
    printf 'unexpected first line: %s\n' "$plain" >&2
    exit 1
    ;;
esac

[ "$(printf '%s' "$plain" | jq -Rs 'length')" -eq 98 ]
