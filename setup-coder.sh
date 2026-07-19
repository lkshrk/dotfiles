#!/usr/bin/env bash
# setup-coder.sh - bootstrap a Coder workspace through the Coder Omni profile.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"

c_red=$'\033[31m'
c_yel=$'\033[33m'
c_grn=$'\033[32m'
c_dim=$'\033[2m'
c_off=$'\033[0m'

say()  { printf '%b\n' "$*"; }
step() { say "${c_dim}==>${c_off} $*"; }
ok()   { say "${c_grn}OK${c_off} $*"; }
warn() { say "${c_yel}!${c_off} $*"; }
die()  { say "${c_red}x${c_off} $*" >&2; exit 1; }

export -f say step ok warn die

[[ "$(uname -s)" == "Linux" ]] || die "setup-coder.sh is Linux-only"
[[ -f "$OMNI_CONFIG_PATH" ]] || die "Omni config not found: $OMNI_CONFIG_PATH"

export REPO_DIR OMNI_CONFIG_PATH
export c_red c_yel c_grn c_dim c_off

source "$REPO_DIR/scripts/setup-coder-linux.sh"

step "omni install"
bash "$REPO_DIR/scripts/install-omni-latest.sh"
omni --config "$OMNI_CONFIG_PATH" settings show --format json >/dev/null 2>&1 \
  || die "installed omni cannot read this repo's config"

export OMNI_HOSTNAME="${CODER_OMNI_HOST:-coder}"

step "omni coder profile"
ok "using Omni host profile: $OMNI_HOSTNAME"

# The Coder host is already declared in the shared config. Do not run
# `omni bootstrap`: its unconditional tool and dots sync happen before this
# script can apply the Coder-specific install order and conflict policy.

step "shell (zsh + oh-my-zsh)"
# oh-my-zsh writes a real ~/.zshrc; drop it before install and again before stow.
rm -f "$HOME/.zshrc"
omni --config "$OMNI_CONFIG_PATH" --yes tools sync shell
rm -f "$HOME/.zshrc"
for _dot in zshenv zshrc zsh env; do
  omni --config "$OMNI_CONFIG_PATH" --yes dots sync --use-repo "$_dot"
done
ok "shell ready: $(command -v zsh 2>/dev/null || printf 'zsh')"

step "toolchain prerequisites"
omni --config "$OMNI_CONFIG_PATH" --yes tools sync prereqs
export_sync_path

step "omni tools"
omni --config "$OMNI_CONFIG_PATH" --yes tools sync --all

# Ubuntu packages bat as `batcat`; keep the cross-platform command name.
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi

# Hard-sync extra language/tooling groups selected on the workspace (CODER_OMNI_STACKS,
# comma-separated), regardless of host membership. e.g. "python,ts,infra".
if [[ -n "${CODER_OMNI_STACKS:-}" ]]; then
  IFS=',' read -r -a _omni_stacks <<< "$CODER_OMNI_STACKS"
  for _stack in "${_omni_stacks[@]}"; do
    _stack="${_stack//[[:space:]]/}"
    [[ -n "$_stack" ]] || continue
    step "omni stack: $_stack"
    omni --config "$OMNI_CONFIG_PATH" --yes tools sync "$_stack"
  done
fi

step "omni dotfiles"
# Coder's codex module writes real ~/.codex files at agent start, the
# oh-my-zsh installer writes a real ~/.zshrc, opencode replaces its config
# symlinks with real files at runtime, and Claude Code rewrites
# .claude/plugins/installed_plugins.json; all collide with the symlinks omni
# wants to stow (--use-repo does not resolve a replaced-symlink conflict).
# Drop them so dots sync links cleanly.
rm -f "$HOME/.codex/config.toml" "$HOME/.codex/mcp.json" "$HOME/.zshrc" \
  "$HOME/.claude/plugins/installed_plugins.json"
rm -rf "$HOME/.config/opencode"
omni --config "$OMNI_CONFIG_PATH" --yes dots sync --use-repo

# Claude Code may update settings at runtime. Keep the Coder copy writable and
# apply its externally-sandboxed workspace policy without mutating dotfiles.
_claude_settings="$HOME/.claude/settings.json"
if [[ -L "$_claude_settings" ]]; then
  cp --remove-destination "$(readlink -f "$_claude_settings")" "$_claude_settings"
fi
if [[ -f "$_claude_settings" ]]; then
  _claude_settings_tmp="$(mktemp)"
  jq '(.permissions //= {})
    | .permissions.defaultMode = "bypassPermissions"
    | .permissions.skipDangerousModePermissionPrompt = true' \
    "$_claude_settings" > "$_claude_settings_tmp"
  mv "$_claude_settings_tmp" "$_claude_settings"
fi

# Codex persists runtime state (hook hashes, bundled marketplace paths) into
# config.toml. Keep Coder's copy writable so that state never mutates the
# stowed, portable template in the dotfiles checkout.
_codex_config="$HOME/.codex/config.toml"
if [[ -L "$_codex_config" ]]; then
  cp --remove-destination "$(readlink -f "$_codex_config")" "$_codex_config"
fi

if [[ -f "$_codex_config" ]]; then
  sed -i -E \
    -e 's|^approval_policy[[:space:]]*=.*|approval_policy = "never"|' \
    -e 's|^default_permissions[[:space:]]*=.*|default_permissions = ":danger-full-access"|' \
    "$_codex_config"
fi

# tools sync may replace ~/.local/bin/node; re-point at the nvm default after stow.
step "nvm local bin links"
sync_nvm_local_bin_links
ok "node links: $(readlink -f "$HOME/.local/bin/node" 2>/dev/null || printf 'updated')"

step "codex telemetry"
if [[ -e "$_codex_config" ]]; then
  if [[ -r /usr/local/share/ca-certificates/lan-ca.crt ]]; then
    sed -i -E \
      -e 's|^([[:space:]]*ca-certificate = ).*|\1"/usr/local/share/ca-certificates/lan-ca.crt"|' \
      "$_codex_config"
    ok "Codex OTEL uses /usr/local/share/ca-certificates/lan-ca.crt"
  else
    sed -i \
      -e '/^[[:space:]]*ca-certificate = /d' \
      "$_codex_config"
    warn "Codex OTEL CA missing; removed explicit ca-certificate entries"
  fi
  sed -i \
    -e 's|https://api\.ai\.h-cloud\.lan/mcp/|http://litellm-proxy.ai.svc.cluster.local:4000/mcp/|' \
    "$_codex_config"
  ok "Codex litellm MCP -> in-cluster service"
else
  warn "Codex config not found after dots sync"
fi

# Omni MCP restore references this binary; the dotfiles copy is macOS-only.
if [[ ! -x "$HOME/.local/bin/codebase-memory-mcp" ]]; then
  step "codebase-memory-mcp"
  arch="$(uname -m)"
  case "$arch" in
    aarch64|arm64)
      asset=codebase-memory-mcp-linux-arm64.tar.gz
      ;;
    x86_64|amd64)
      asset=codebase-memory-mcp-linux-amd64.tar.gz
      ;;
    *)
      asset=""
      warn "codebase-memory-mcp has no Linux release for architecture: $arch"
      ;;
  esac
  if [[ -n "$asset" ]]; then
    curl -fsSL "https://github.com/DeusData/codebase-memory-mcp/releases/latest/download/$asset" \
      | tar -xz -C "$HOME/.local/bin" codebase-memory-mcp \
      || warn "codebase-memory-mcp install failed; omni MCP restore may skip it"
  fi
fi

bash "$REPO_DIR/scripts/bootstrap-agents.sh"

if [[ -f "$HOME/.claude.json" ]]; then
  step "litellm MCP in-cluster URL (claude)"
  sed -i \
    -e 's|https://api\.ai\.h-cloud\.lan/mcp/|http://litellm-proxy.ai.svc.cluster.local:4000/mcp/|g' \
    "$HOME/.claude.json"
  ok "claude litellm MCP -> in-cluster service"
fi

# Activate git hooks in the project repos the template clones. The git-clone
# module runs in parallel with this bootstrap, so wait briefly for each clone.
# CODER_REPO_DIRS: comma-separated folder names under $HOME, set by the template.
if [[ -n "${CODER_REPO_DIRS:-}" ]]; then
  step "lefthook hooks"
  if PATH="$HOME/.local/bin:$PATH" command -v lefthook >/dev/null 2>&1; then
    IFS=',' read -r -a _repo_dirs <<< "$CODER_REPO_DIRS"
    for _repo in "${_repo_dirs[@]}"; do
      _repo="${_repo//[[:space:]]/}"
      [[ -n "$_repo" ]] || continue
      _repo_path="$HOME/$_repo"
      for _ in $(seq 1 60); do
        [[ -d "$_repo_path/.git" ]] && break
        sleep 5
      done
      if [[ ! -d "$_repo_path/.git" ]]; then
        warn "repo never appeared at $_repo_path; skipping lefthook install"
        continue
      fi
      if compgen -G "$_repo_path/lefthook.y*ml" >/dev/null || compgen -G "$_repo_path/.lefthook.y*ml" >/dev/null; then
        if (cd "$_repo_path" && PATH="$HOME/.local/bin:$PATH" lefthook install); then
          ok "lefthook hooks installed in $_repo_path"
        else
          warn "lefthook install failed in $_repo_path"
        fi
      else
        ok "no lefthook config in $_repo_path; nothing to do"
      fi
    done
  else
    warn "lefthook binary missing; skipping repo hook install"
  fi
fi

# Prewarm nvim plugins headlessly so the first interactive launch is instant.
# Needs both the binary (tools sync) and the stowed config (dots sync above).
if command -v nvim >/dev/null 2>&1 || [ -x "$HOME/.local/bin/nvim" ]; then
  step "nvim plugins"
  if PATH="$HOME/.local/bin:$PATH" nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 \
    || PATH="$HOME/.local/bin:$PATH" nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1
  then
    step "nvim Mason tools"
    PATH="$HOME/.local/bin:$PATH" nvim --headless "+MasonToolsInstallSync" +qa >/dev/null 2>&1 \
      || warn "nvim Mason tool install failed; tools will install on first launch"
  else
    warn "nvim plugin sync failed; plugins will install on first launch"
  fi
fi

activate_zsh_login_shell
