#!/usr/bin/env bash
# restore-skills.sh — Restore agent skills and Claude plugins from lockfiles.
set -euo pipefail

SKILL_LOCK="$HOME/.agents/.skill-lock.json"

# Non-interactive: auto-yes for skills, skip doctor
is_interactive() { [[ -t 0 && -t 1 ]]; }

# ─── Agent Skills ─────────────────────────────────────────────────────────────

if [[ -f "$SKILL_LOCK" ]]; then
  count=$(python3 -c "import json; print(len(json.load(open('$SKILL_LOCK'))['skills']))" 2>/dev/null || echo "?")
  echo "Found skill lockfile ($count skills): $SKILL_LOCK"
  if is_interactive; then
    read -rp "Restore agent skills from lockfile? [y/N] " answer
  else
    answer="y"
    echo "Non-interactive: auto-restoring skills"
  fi
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    bunx skills@latest experimental_install
  else
    echo "Skipped"
  fi
else
  echo "No skill lockfile at $SKILL_LOCK"
fi

echo ""

# ─── Claude Doctor ────────────────────────────────────────────────────────────

if is_interactive; then
  read -rp "Run claude doctor? [y/N] " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    claude doctor
  fi
else
  echo "Non-interactive: skipping claude doctor"
fi
