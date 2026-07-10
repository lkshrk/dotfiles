#!/bin/bash
# Hard-deny Write/Edit to .wolf/, .omc/, .omx/ outside a git repository.
# Keeps throwaway (non-repo) dirs clean. Silent allow on anything else.
input=$(cat)
fp=$(printf '%s' "$input" | /usr/bin/python3 -c "import sys,json
try:
    print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))
except Exception:
    print('')" 2>/dev/null)
case "$fp" in
  *.wolf/*|*.omc/*|*.omx/*|*/CLAUDE.md|CLAUDE.md|*/CLAUDE.local.md|CLAUDE.local.md)
    dir="${CLAUDE_PROJECT_DIR:-$PWD}"
    if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Not a git repo — agent file creation (.wolf/.omc/.omx/CLAUDE.md) disabled here."}}'
    fi
    ;;
esac
exit 0
