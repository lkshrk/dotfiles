#!/bin/sh
set -eu

herdr=${HERDR_BIN_PATH:-herdr}
cwd=$("$herdr" pane current | jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty')
repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
branch=$(git -C "$repo_root" branch --show-current)
[ -n "$branch" ] || branch=$(git -C "$repo_root" rev-parse --short HEAD)

"$herdr" terminal title set "HERDR - < ${repo_root##*/}[$branch]"
