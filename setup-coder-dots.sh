#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_DIR/scripts/coder-bootstrap.sh"

coder_dots_main() (
  local argument="${1:-}" config client target pending_client=""
  [[ $# -le 1 && ( -z "$argument" || "$argument" == --print-config ) ]] || die "usage: ./setup-coder-dots.sh [--print-config]"
  command -v python3 >/dev/null || die "dots setup requires system python3"
  if [[ "$argument" == --print-config ]]; then
    python3 "$REPO_DIR/scripts/coder-dots.py"
    return
  fi
  [[ "$(uname -s)" == Linux ]] || die "dots setup is Linux-only"
  # omni itself is auto-code-env's install-stacks.py's responsibility
  # (it runs first and installs/verifies it); this script only expects
  # it already on PATH, same as it expects jq/git/python3.
  for binary in jq omni; do
    command -v "$binary" >/dev/null || die "dots setup requires $binary"
  done
  config="$(mktemp)"
  trap 'status=$?; if [[ -n "$pending_client" ]]; then bash "$REPO_DIR/scripts/volatile-dots.sh" detach "$pending_client"; fi; rm -f "$config"; exit "$status"' EXIT
  python3 "$REPO_DIR/scripts/coder-dots.py" > "$config"
  export OMNI_HOSTNAME=coder-components
  export CODER_ENVIRONMENT_MODE=composable
  install_ghostty_terminfo
  while IFS= read -r client; do
    [[ ! -L "$HOME/.$client" ]] || die "refusing symlinked client directory: $HOME/.$client"
    mkdir -p "$HOME/.$client"
    bash "$REPO_DIR/scripts/volatile-dots.sh" detach "$client"
    pending_client="$client"
    bash "$REPO_DIR/scripts/volatile-dots.sh" prepare "$client"
    if ! omni --config "$config" --yes dots sync --use-repo "$client"; then
      bash "$REPO_DIR/scripts/volatile-dots.sh" detach "$client"
      die "required client configuration sync failed: $client"
    fi
    bash "$REPO_DIR/scripts/volatile-dots.sh" detach "$client"
    pending_client=""
    case "$client" in
      claude) target="$HOME/.claude/CLAUDE.md"; [[ -f "$HOME/.claude/settings.json" ]] || die "Claude settings missing" ;;
      codex) target="$HOME/.codex/AGENTS.md"; [[ -f "$HOME/.codex/config.toml" ]] || die "Codex config missing" ;;
    esac
    [[ -f "$target" ]] || printf '# Workspace instructions\n' > "$target"
    install_coder_workspace_notes "$target"
  done < <(jq -r '.groups[] | select(.name == "component-clients") | .dots[].name' "$config")
  if [[ "${CODER_AGENT_PLUGINS:-0}" == 1 ]]; then
    warn "CODER_AGENT_PLUGINS installs auxiliary plugin tools only; no APM skills, marketplace plugins, hooks, or MCP registrations are provisioned"
  fi
  python3 "$REPO_DIR/scripts/coder-client-config.py" --clients "${CODER_AGENT_CLIENTS:-}"
  python3 "$REPO_DIR/scripts/coder-core.py" check-dots "$config"
  while IFS= read -r target; do
    omni --config "$config" --yes dots sync "$target" || die "required core config sync failed: $target; resolve local conflicts and retry"
  done < <(jq -r '.groups[] | select(.name == "component-core-dots") | .dots[].name' "$config")
  python3 "$REPO_DIR/scripts/coder-core.py" verify-dots "$config"
  python3 "$REPO_DIR/scripts/coder-core.py" hooks
  ok "required Coder dots ready"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  coder_dots_main "$@"
fi
