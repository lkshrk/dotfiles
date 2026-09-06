#!/usr/bin/env bash
# setup-coder.sh - add Coder-specific policy to the shared Linux workspace setup.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_DIR/setup-workspace.sh"

install_coder_workspace_notes() {
  local target temporary docker_note
  local -a targets=("$@")
  if [[ ${#targets[@]} == 0 ]]; then
    targets=("$HOME/.codex/AGENTS.md" "$HOME/.claude/CLAUDE.md")
  fi
  case "${CODER_ENABLE_DIND:-0}" in
    1) docker_note='- Docker is available through Docker-in-Docker (DinD).' ;;
    0) docker_note='- Docker-in-Docker (DinD) is not enabled. Do not assume a Docker daemon is available.' ;;
    *) warn "CODER_ENABLE_DIND must be 0 or 1"; return 1 ;;
  esac
  for target in "${targets[@]}"; do
    [[ -f "$target" ]] || {
      warn "workspace instructions not found: $target"
      continue
    }
    temporary="$(mktemp "$(dirname "$target")/.coder-notes.XXXXXX")"
    if ! awk -v docker="$docker_note" '
      function block() {
        print "<!-- coder-workspace:start -->"
        print "## Coder workspace\n"
        print docker
        print "- Git SSH operations must preserve and use the existing `$GIT_SSH_COMMAND`. Do not unset, replace, or bypass it."
        print "<!-- coder-workspace:end -->"
      }
      /^<!-- coder-workspace:start -->$/ {
        if (!found++) block()
        inside = 1
        next
      }
      /^<!-- coder-workspace:end -->$/ { inside = 0; next }
      !inside { print }
      END {
        if (inside) exit 1
        if (!found) { print ""; block() }
      }
    ' "$target" > "$temporary"; then
      rm -f "$temporary"
      warn "unterminated Coder workspace notes: $target"
      return 1
    fi
    chmod --reference="$target" "$temporary"
    mv -f "$temporary" "$target"
  done
}

sync_nvm_local_bin_links() {
  local nvm_node_bin="${1:-}"
  local env_nvm_lib="${REPO_DIR}/dotfiles/env/.config/env/lib/nvm-node.sh"

  if [[ -z "$nvm_node_bin" && -r "$env_nvm_lib" ]]; then
    # shellcheck source=/dev/null
    . "$env_nvm_lib"
    nvm_node_bin="$(env_next_nvm_resolve_bin default 2>/dev/null || true)"
    unset -f env_next_nvm_alias_target env_next_nvm_best_dir_from_candidates 2>/dev/null || true
    unset -f env_next_nvm_resolve_dir env_next_nvm_resolve_bin 2>/dev/null || true
  fi

  if [[ -z "$nvm_node_bin" && -n "${NVM_BIN:-}" ]]; then
    nvm_node_bin="$NVM_BIN"
  fi

  [[ -n "$nvm_node_bin" && -x "$nvm_node_bin/node" ]] || return 0

  mkdir -p "$HOME/.local/bin"
  local bin
  for bin in node npm npx corepack; do
    [[ -x "$nvm_node_bin/$bin" ]] && ln -sf "$nvm_node_bin/$bin" "$HOME/.local/bin/$bin"
  done
  return 0
}

workspace_after_linux() {
  source "$REPO_DIR/scripts/setup-coder-linux.sh"
}

workspace_before_dots() {
  bash "$REPO_DIR/scripts/volatile-dots.sh" prepare
}

workspace_after_dots() {
  bash "$REPO_DIR/scripts/volatile-dots.sh" detach
  install_coder_workspace_notes

  local claude_settings="$HOME/.claude/settings.json"
  if [[ -f "$claude_settings" ]]; then
    local claude_settings_tmp
    claude_settings_tmp="$(mktemp)"
    jq '(.permissions //= {})
      | .permissions.defaultMode = "bypassPermissions"
      | .permissions.skipDangerousModePermissionPrompt = true' \
      "$claude_settings" > "$claude_settings_tmp"
    mv "$claude_settings_tmp" "$claude_settings"
  fi

  local codex_config="$HOME/.codex/config.toml"
  if [[ -f "$codex_config" ]]; then
    sed -i -E \
      -e 's|^approval_policy[[:space:]]*=.*|approval_policy = "never"|' \
      -e 's|^default_permissions[[:space:]]*=.*|default_permissions = ":danger-full-access"|' \
      "$codex_config"
  fi

  step "nvm local bin links"
  sync_nvm_local_bin_links
  ok "node links: $(readlink -f "$HOME/.local/bin/node" 2>/dev/null || printf 'updated')"

  step "codex telemetry"
  if [[ -e "$codex_config" ]]; then
    if [[ -r /usr/local/share/ca-certificates/lan-ca.crt ]]; then
      sed -i -E \
        -e 's|^([[:space:]]*ca-certificate = ).*|\1"/usr/local/share/ca-certificates/lan-ca.crt"|' \
        "$codex_config"
      ok "Codex OTEL uses /usr/local/share/ca-certificates/lan-ca.crt"
    else
      sed -i \
        -e '/^[[:space:]]*ca-certificate = /d' \
        "$codex_config"
      warn "Codex OTEL CA missing; removed explicit ca-certificate entries"
    fi
  else
    warn "Codex config not found after dots sync"
  fi

  if [[ -n "${CODER_MCP_URL:-}" ]]; then
    python3 "$REPO_DIR/scripts/coder-client-config.py"
    ok "applied explicit CODER_MCP_URL"
  fi
}

workspace_after_setup() {
  if [[ -z "${CODER_REPO_DIRS:-}" ]]; then
    return
  fi

  step "lefthook hooks"
  if PATH="$HOME/.local/bin:$PATH" command -v lefthook >/dev/null 2>&1; then
    local repo repo_path
    local -a repos
    IFS=',' read -r -a repos <<< "$CODER_REPO_DIRS"
    for repo in "${repos[@]}"; do
      repo="${repo//[[:space:]]/}"
      [[ -n "$repo" ]] || continue
      repo_path="$HOME/$repo"
      for _ in $(seq 1 60); do
        [[ -d "$repo_path/.git" ]] && break
        sleep 5
      done
      if [[ ! -d "$repo_path/.git" ]]; then
        warn "repo never appeared at $repo_path; skipping lefthook install"
        continue
      fi
      if compgen -G "$repo_path/lefthook.y*ml" >/dev/null || compgen -G "$repo_path/.lefthook.y*ml" >/dev/null; then
        if (cd "$repo_path" && PATH="$HOME/.local/bin:$PATH" lefthook install); then
          ok "lefthook hooks installed in $repo_path"
        else
          warn "lefthook install failed in $repo_path"
        fi
      else
        ok "no lefthook config in $repo_path; nothing to do"
      fi
    done
  else
    warn "lefthook binary missing; skipping repo hook install"
  fi
}

export WORKSPACE_OMNI_STACKS="${CODER_OMNI_STACKS:-}"
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  setup_workspace_main "${CODER_OMNI_HOST:-coder}"
fi
