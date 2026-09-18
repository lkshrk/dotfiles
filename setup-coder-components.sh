#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_DIR/scripts/coder-bootstrap.sh"
source "$REPO_DIR/scripts/install-omni-latest.sh"

coder_components_omni_compatible() {
  local config="$1" binary="${2:-omni}" version
  command -v "$binary" >/dev/null 2>&1 || return 1
  if [[ -n "${OMNI_VERSION:-}" ]]; then
    version="$("$binary" --version)" || return 1
    [[ "$version" =~ ^omni\ version\ v?([0-9]+\.[0-9]+\.[0-9]+)(\ |$) ]] || return 1
    [[ "${BASH_REMATCH[1]}" == "${OMNI_VERSION#v}" ]] || return 1
  fi
  "$binary" --config "$config" settings show --format json >/dev/null 2>&1
}

coder_components_link_local_bin() {
  local source="$1" target="$HOME/.local/bin/$2" state="$HOME/.local/state/coder-components/links" previous
  [[ "$2" =~ ^[a-zA-Z0-9][a-zA-Z0-9._+-]*$ ]] || die "invalid executable name: $2"
  [[ ! -L "$state" && ! -L "${state%/*}" ]] || die "refusing symlinked link receipt directory: $state"
  mkdir -p "$HOME/.local/bin" "$state"
  [[ ! -L "$state/$2" ]] || die "refusing symlinked link receipt: $state/$2"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    # Already correct, but write/refresh the receipt even on this fast
    # path: without it, a link that reached the right target by any
    # means other than this function (a prior run before receipts
    # existed, or an external actor) can never be retargeted later --
    # the ownership check below would see no receipt and die().
    printf '%s\n' "$source" > "$state/$2"
    return 0
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -L "$target" && -f "$state/$2" ]] || die "refusing to replace existing executable path: $target (wanted $source)"
    previous="$(cat "$state/$2")"
    [[ "$(readlink "$target")" == "$previous" ]] || die "refusing to replace modified executable path: $target"
    ln -sfnT "$source" "$target"
  else
    ln -sT "$source" "$target"
  fi
  printf '%s\n' "$source" > "$state/$2"

}

coder_components_link_node_commands() {
  local node_bin="$1" binary
  [[ "$node_bin" == /* && -x "$node_bin/node" ]] || die "required Node executable missing: $node_bin/node"
  for binary in node npm npx corepack; do
    [[ -x "$node_bin/$binary" ]] && coder_components_link_local_bin "$node_bin/$binary" "$binary"
  done
  return 0
}

coder_components_path() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if jq -e '.tools | has("nvm")' "$1" >/dev/null && [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh" --no-use
    nvm use --silent default >/dev/null
    coder_components_link_node_commands "$NVM_BIN"
  fi
  export PATH="${NVM_BIN:+$NVM_BIN:}$HOME/.local/bin:$HOME/.bun/bin:$HOME/.cargo/bin:$HOME/.krew/bin:$HOME/.local/share/pnpm:$HOME/.local/share/pnpm/bin:$PATH"
}

coder_components_link_npm_commands() {
  local config="$1" required prefix binary stable_path
  required="$(python3 "$REPO_DIR/scripts/coder-components.py" --required-commands "$config" --required-provider npm)"
  [[ -n "$required" ]] || return 0
  prefix="$(npm prefix -g)" || die "cannot resolve npm global prefix"
  [[ "$prefix" == /* ]] || die "npm global prefix must be absolute: $prefix"
  stable_path="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.cargo/bin:$HOME/.krew/bin:$HOME/.local/share/pnpm:/bin"
  while IFS= read -r binary; do
    [[ -x "$prefix/bin/$binary" ]] || die "required npm executable missing: $prefix/bin/$binary"
    coder_components_link_local_bin "$prefix/bin/$binary" "$binary"
    env -u NVM_BIN PATH="$stable_path" "$binary" --version >/dev/null || die "required npm executable failed on stable PATH: $binary"
  done <<< "$required"
}

coder_components_link_lsp_commands() {
  local config="$1" prefix
  if jq -e '.tools | has("pyright")' "$config" >/dev/null; then
    prefix="$(npm prefix -g)" || die "cannot resolve Pyright language server prefix"
    [[ "$prefix" == /* && -x "$prefix/bin/pyright-langserver" ]] || die "required Pyright language server missing"
    coder_components_link_local_bin "$prefix/bin/pyright-langserver" pyright-langserver
    node --check "$prefix/bin/pyright-langserver" || die "invalid Pyright language server entrypoint"
  fi
}

coder_components_refresh_apt() {
  local config="$1" package
  while IFS= read -r package; do
    if [[ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true)" != 'install ok installed' ]]; then
      command -v apt-get >/dev/null || die "required component packages need Debian/Ubuntu apt"
      if [[ "$(id -u)" == 0 ]]; then
        apt-get update -qq
      elif command -v sudo >/dev/null; then
        sudo -n apt-get update -qq
      else
        die "missing required apt packages need root or passwordless sudo"
      fi
      return
    fi
  done < <(jq -r '. as $root | .groups[] | .tools[]? as $name | $root.tools[$name].providers | map(select(.provider != "brew")) | select(length == 1 and .[0].provider == "apt") | .[0].package // $name' "$config")
}

coder_components_check() {
  local config="$1" binary required tree_sitter_version
  required="$(python3 "$REPO_DIR/scripts/coder-components.py" --required-commands "$config")"
  while IFS= read -r binary; do
    command -v "$binary" >/dev/null 2>&1 || die "required component binary missing: $binary"
  done <<< "$required"
  [[ -r "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] || die "required Oh My Zsh configuration missing"
  tree_sitter_version="$(tree-sitter --version)"
  python3 -c 'import re,sys; match=re.search(r"(\d+)\.(\d+)\.(\d+)",sys.argv[1]); sys.exit(0 if match and tuple(map(int,match.groups())) >= (0,26,1) else 1)' "$tree_sitter_version" || die "tree-sitter >=0.26.1 required"
  nvim --headless -u NONE -i NONE '+lua if vim.fn.filereadable(vim.env.VIMRUNTIME .. "/doc/help.txt") ~= 1 then vim.cmd("cquit") end' +qa || die "required Neovim runtime is incomplete"
  if jq -e '.tools | has("python@3.14")' "$config" >/dev/null; then
    uv python find 3.14 >/dev/null || die "required managed Python 3.14 missing"
  fi
}

coder_components_main() (
  local argument="${1:-}" config group client target binary pending_client=""
  [[ $# -le 1 && ( -z "$argument" || "$argument" == --print-config ) ]] || die "usage: ./setup-coder-components.sh [--print-config]"
  command -v python3 >/dev/null || die "component bootstrap requires system python3"
  omni_release_base >/dev/null
  if [[ "$argument" == --print-config ]]; then
    python3 "$REPO_DIR/scripts/coder-components.py"
    return
  fi
  [[ "$(uname -s)" == Linux ]] || die "component setup is Linux-only"
  for binary in curl tar git jq; do
    command -v "$binary" >/dev/null || die "component bootstrap requires $binary"
  done
  config="$(mktemp)"
  trap 'status=$?; if [[ -n "$pending_client" ]]; then bash "$REPO_DIR/scripts/volatile-dots.sh" detach "$pending_client"; fi; rm -f "$config"; exit "$status"' EXIT
  python3 "$REPO_DIR/scripts/coder-components.py" > "$config"
  export PATH="$HOME/.local/bin:$PATH"
  export OMNI_HOSTNAME=coder-components
  export CODER_ENVIRONMENT_MODE=composable
  if [[ -n "${OMNI_OTEL_CA_PATH:-}" && -r "$OMNI_OTEL_CA_PATH" ]]; then
    export NODE_EXTRA_CA_CERTS="${NODE_EXTRA_CA_CERTS:-$OMNI_OTEL_CA_PATH}"
  fi
  if coder_components_omni_compatible "$config"; then
    ok "reusing compatible $(omni --version)"
  else
    bash "$REPO_DIR/scripts/install-omni-latest.sh"
  fi
  omni --config "$config" settings show --format json >/dev/null
  coder_components_refresh_apt "$config"
  while IFS= read -r group; do
    step "required component tools: $group"
    omni --config "$config" --yes tools sync "$group"
    coder_components_path "$config"
  done < <(jq -r '.groups[] | select((.tools // []) | length > 0) | .name' "$config")
  if command -v batcat >/dev/null; then
    coder_components_link_local_bin "$(command -v batcat)" bat
  fi
  if command -v fdfind >/dev/null; then
    coder_components_link_local_bin "$(command -v fdfind)" fd
  fi
  install_ghostty_terminfo
  coder_components_link_npm_commands "$config"
  coder_components_link_lsp_commands "$config"
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
  coder_components_check "$config"
  ok "required Coder components ready; backend=${CODER_BACKEND:-kubernetes}, DinD=${CODER_ENABLE_DIND:-0} (daemon owned by parent)"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  coder_components_main "$@"
fi
