#!/usr/bin/env bash
# scripts/pre-push-sync.sh — invoked by lefthook pre-push.
#
# Asks whether to run `dotsync` before pushing. Skips silently when running
# non-interactively (CI, scripted pushes) so it doesn't block automation.

set -euo pipefail

# Non-interactive shells (CI, hook chains, no tty) — skip.
if [[ ! -t 0 || ! -t 1 ]]; then
  exit 0
fi

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

printf 'Run dotsync before pushing? [y/N] '
read -r reply </dev/tty || exit 0

case "$reply" in
  [Yy]*) bash "$DOTFILES_DIR/scripts/sync.sh" ;;
  *)     echo "skipping sync" ;;
esac
