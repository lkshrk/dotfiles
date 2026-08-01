#!/usr/bin/env bash
# bootstrap-agents.sh — Sync agent skills, MCP servers, and plugins via omni.
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"

# 'command' would bypass the functions setup-coder.sh exports; call them directly.
_bootstrap_say()  { if declare -F say  >/dev/null 2>&1; then say  "$@"; else printf '%s\n' "$@"; fi; }
_bootstrap_step() { if declare -F step >/dev/null 2>&1; then step "$@"; else printf '==> %s\n' "$*"; fi; }
_bootstrap_ok()   { if declare -F ok   >/dev/null 2>&1; then ok   "$@"; else _bootstrap_say "OK $*"; fi; }
_bootstrap_warn() { if declare -F warn >/dev/null 2>&1; then warn "$@"; else _bootstrap_say "! $*" >&2; fi; }
_bootstrap_die()  { if declare -F die  >/dev/null 2>&1; then die  "$@"; else _bootstrap_say "x $*" >&2; exit 1; fi; }

export_agent_path() {
  export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"
}

if ! command -v omni >/dev/null 2>&1; then
  _bootstrap_die "omni is not installed"
fi

export_agent_path

if [[ -z "${NODE_EXTRA_CA_CERTS:-}" && -r "${OMNI_OTEL_CA_PATH:-}" ]]; then
  export NODE_EXTRA_CA_CERTS="$OMNI_OTEL_CA_PATH"
fi

omni_cmd() {
  if [[ -f "$OMNI_CONFIG_PATH" ]]; then
    omni --config "$OMNI_CONFIG_PATH" --yes "$@"
  else
    omni --yes "$@"
  fi
}

agents_sync_available() {
  omni_cmd agents skills sync --help >/dev/null 2>&1 \
    && omni_cmd agents mcp sync --help >/dev/null 2>&1 \
    && omni_cmd agents plugins sync --help >/dev/null 2>&1
}

if ! agents_sync_available; then
  _bootstrap_die "installed omni does not support agents sync; update omni and rerun setup"
fi

sync_component() {
  local label="$1"
  shift
  _bootstrap_step "omni agents $label"
  if omni_cmd "$@" sync; then
    _bootstrap_ok "agent $label sync complete"
  else
    _bootstrap_warn "agent $label sync had errors"
  fi
}

_bootstrap_step "omni agents"
# Plugin marketplace snapshots must be present before MCP sync. The latter
# runs Codex's plugin-shadow check, which otherwise reads stale snapshots from
# a previous workspace start and emits a spurious missing-manifest warning.
sync_component plugins agents plugins
sync_component skills agents skills
sync_component mcp agents mcp
