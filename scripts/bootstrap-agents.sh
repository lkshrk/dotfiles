#!/usr/bin/env bash
# bootstrap-agents.sh — Restore agent skills, MCP servers, and plugins via omni.
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"
OMNI_MIN_VERSION="${OMNI_MIN_VERSION:-0.8.8}"
OMNI_AGENTS_REQUIRED="${OMNI_AGENTS_REQUIRED:-0}"

# 'command' would bypass the functions setup-coder.sh exports; call them directly.
_bootstrap_say()  { if declare -F say  >/dev/null 2>&1; then say  "$@"; else printf '%s\n' "$@"; fi; }
_bootstrap_step() { if declare -F step >/dev/null 2>&1; then step "$@"; else printf '==> %s\n' "$*"; fi; }
_bootstrap_ok()   { if declare -F ok   >/dev/null 2>&1; then ok   "$@"; else _bootstrap_say "OK $*"; fi; }
_bootstrap_warn() { if declare -F warn >/dev/null 2>&1; then warn "$@"; else _bootstrap_say "! $*" >&2; fi; }
_bootstrap_die()  { if declare -F die  >/dev/null 2>&1; then die  "$@"; else _bootstrap_say "x $*" >&2; exit 1; fi; }

omni_version() {
  omni --version 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+(\.[0-9]+){1,2}$/) { print $i; exit } }'
}

version_at_least() {
  awk -v current="$1" -v minimum="$2" 'BEGIN {
    split(current, c, ".")
    split(minimum, m, ".")
    for (i = 1; i <= 3; i++) {
      c[i] += 0
      m[i] += 0
      if (c[i] > m[i]) exit 0
      if (c[i] < m[i]) exit 1
    }
    exit 0
  }'
}

export_agent_path() {
  export PATH="$HOME/.grok/bin:$HOME/.bun/bin:$HOME/.local/bin:$PATH"
}

if ! command -v omni >/dev/null 2>&1; then
  if [[ "$OMNI_AGENTS_REQUIRED" == "1" ]]; then
    _bootstrap_die "omni is not installed"
  fi
  _bootstrap_warn "omni not found; skipping agent restore"
  exit 0
fi

current="$(omni_version)"
if [[ -z "$current" ]] || ! version_at_least "$current" "$OMNI_MIN_VERSION"; then
  if [[ "$OMNI_AGENTS_REQUIRED" == "1" ]]; then
    _bootstrap_die "omni $OMNI_MIN_VERSION or newer is required for agents restore (found: ${current:-unknown})"
  fi
  _bootstrap_warn "omni ${current:-unknown} is older than $OMNI_MIN_VERSION; skipping agent restore"
  exit 0
fi

export_agent_path

omni_cmd() {
  if [[ -f "$OMNI_CONFIG_PATH" ]]; then
    omni --config "$OMNI_CONFIG_PATH" --yes "$@"
  else
    omni --yes "$@"
  fi
}

agents_restore_available() {
  omni_cmd agents skills restore --help >/dev/null 2>&1 \
    && omni_cmd agents mcp restore --help >/dev/null 2>&1 \
    && omni_cmd agents plugins restore --help >/dev/null 2>&1
}

if ! agents_restore_available; then
  if [[ "$OMNI_AGENTS_REQUIRED" == "1" ]]; then
    _bootstrap_die "installed omni does not support agents restore; update omni and rerun setup"
  fi
  _bootstrap_warn "omni agents restore is unavailable; skipping"
  exit 0
fi

restore_component() {
  local label="$1"
  shift
  _bootstrap_step "omni agents $label"
  if omni_cmd "$@" restore; then
    _bootstrap_ok "agent $label restore complete"
  else
    _bootstrap_warn "agent $label restore had errors"
  fi
}

_bootstrap_step "omni agents"
restore_component skills agents skills
restore_component mcp agents mcp
restore_component plugins agents plugins