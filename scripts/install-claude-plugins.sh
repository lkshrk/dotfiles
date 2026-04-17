#!/usr/bin/env bash
# scripts/install-claude-plugins.sh — re-install Claude Code plugins from
# the tracked installed_plugins.json manifest.

set -euo pipefail

MANIFEST="$HOME/.claude/plugins/installed_plugins.json"

command -v claude >/dev/null || { echo "claude CLI not found"; exit 1; }
command -v jq     >/dev/null || { echo "jq not installed (brew install jq)"; exit 1; }
[[ -s "$MANIFEST" ]] || { echo "manifest missing: $MANIFEST"; exit 1; }

# Each key in `.plugins` looks like "<name>@<marketplace>".
mapfile -t plugins < <(jq -r '.plugins | keys[]' "$MANIFEST")

if (( ${#plugins[@]} == 0 )); then
  echo "no plugins listed in manifest"
  exit 0
fi

echo "Installing ${#plugins[@]} plugin(s) from $MANIFEST"
for spec in "${plugins[@]}"; do
  echo "  → $spec"
  claude plugin install "$spec" || echo "    (failed: $spec)"
done

echo "done"
