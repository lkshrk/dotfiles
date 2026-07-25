#!/usr/bin/env bash
# scripts/dots-sync-back.sh - push non-volatile dotfile edits from this
# checkout to a review branch. Volatile runtime files (volatile-dots.txt)
# never leave the machine.
#
# Usage: dots-sync-back.sh [--yes]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="$REPO_DIR/scripts/volatile-dots.txt"
YES=0
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && YES=1

cd "$REPO_DIR"

excludes=()
while IFS= read -r entry; do
  [[ -n "$entry" && "$entry" != \#* ]] || continue
  excludes+=(":(exclude)$entry")
done < "$LIST"

changes="$(git status --porcelain -- . "${excludes[@]}")"
if [[ -z "$changes" ]]; then
  echo "nothing to sync back (clean tree or volatile-only changes)"
  exit 0
fi

echo "changes to sync back:"
printf '%s\n' "$changes"
echo
git --no-pager diff --stat -- . "${excludes[@]}"
echo

if [[ "$YES" != 1 ]]; then
  read -r -p "commit + push these to a review branch? [y/N] " reply
  [[ "$reply" == [yY]* ]] || exit 1
fi

ws="${CODER_WORKSPACE_NAME:-$(hostname -s)}"
branch="coder/${ws}-sync-$(date +%Y%m%d-%H%M%S)"
prev="$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)"

git checkout -b "$branch"
git add -A -- . "${excludes[@]}"
git commit -m "dots: sync-back from ${ws}"
git push -u origin "$branch"
git checkout "$prev"

echo "pushed ${branch}"
echo "review elsewhere with: git fetch origin && git diff main...origin/${branch}"
