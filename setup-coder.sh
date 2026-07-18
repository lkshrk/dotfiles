#!/usr/bin/env bash
# setup-coder.sh - bootstrap a Coder workspace through the Coder Omni profile.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"
CODER_OMNI_HOST="${CODER_OMNI_HOST:-coder}"
RUN_MACOS_DEFAULTS=0
SKIP_ADMIN_WARMUP=1

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

omni_reads_config() {
  command -v omni >/dev/null 2>&1 \
    && omni --config "$OMNI_CONFIG_PATH" settings show --format json >/dev/null 2>&1
}

[[ "$(uname -s)" == "Linux" ]] || die "setup-coder.sh is Linux-only"
[[ -f "$OMNI_CONFIG_PATH" ]] || die "Omni config not found: $OMNI_CONFIG_PATH"

export REPO_DIR OMNI_CONFIG_PATH RUN_MACOS_DEFAULTS SKIP_ADMIN_WARMUP
export c_red c_yel c_grn c_dim c_off

source "$REPO_DIR/scripts/setup-coder-linux.sh"

step "omni install"
bash "$REPO_DIR/scripts/install-omni-latest.sh"
omni --config "$OMNI_CONFIG_PATH" settings show --format json >/dev/null 2>&1 \
  || die "installed omni cannot read this repo's config"

export OMNI_HOSTNAME="$CODER_OMNI_HOST"
export DOTFILES_DIR="${DOTFILES_DIR:-$REPO_DIR}"

mkdir -p "$HOME/.local/bin"
ln -sf "$REPO_DIR/scripts/capture-coder-dotfiles" \
  "$HOME/.local/bin/capture-coder-dotfiles"

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
unset _dot
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
  unset _omni_stacks _stack
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
  _claude_settings_template="$(readlink -f "$_claude_settings")"
  rm "$_claude_settings"
  cp "$_claude_settings_template" "$_claude_settings"
  unset _claude_settings_template
fi
if [[ -f "$_claude_settings" ]]; then
  _claude_settings_tmp="$(mktemp)"
  jq '(.permissions //= {})
    | .permissions.defaultMode = "bypassPermissions"
    | .permissions.skipDangerousModePermissionPrompt = true' \
    "$_claude_settings" > "$_claude_settings_tmp"
  mv "$_claude_settings_tmp" "$_claude_settings"
  unset _claude_settings_tmp
fi
unset _claude_settings

# Codex persists runtime state (hook hashes, bundled marketplace paths) into
# config.toml. Keep Coder's copy writable so that state never mutates the
# stowed, portable template in the dotfiles checkout.
_codex_config="$HOME/.codex/config.toml"
if [[ -L "$_codex_config" ]]; then
  _codex_config_template="$(readlink -f "$_codex_config")"
  rm "$_codex_config"
  cp "$_codex_config_template" "$_codex_config"
  unset _codex_config_template
fi

if [[ -f "$_codex_config" ]]; then
  _codex_config_tmp="$(mktemp)"
  awk '
    BEGIN {
      saw_approval = 0
      saw_default_permissions = 0
      inserted = 0
    }
    function insert_coder_permissions() {
      if (inserted) return
      if (!saw_approval) print "approval_policy = \"never\""
      if (!saw_default_permissions) print "default_permissions = \":danger-full-access\""
      inserted = 1
    }
    /^\[/ {
      insert_coder_permissions()
      print
      next
    }
    /^approval_policy[[:space:]]*=/ {
      print "approval_policy = \"never\""
      saw_approval = 1
      next
    }
    /^default_permissions[[:space:]]*=/ {
      print "default_permissions = \":danger-full-access\""
      saw_default_permissions = 1
      next
    }
    { print }
    END {
      insert_coder_permissions()
    }
  ' "$_codex_config" > "$_codex_config_tmp"
  mv "$_codex_config_tmp" "$_codex_config"

  # node_repl points at a Codex.app path that only exists on macOS.
  _codex_config_tmp="$(mktemp)"
  awk '
    /^\[/ { drop = ($0 ~ /^\[mcp_servers\.node_repl[\].]/) }
    !drop { print }
  ' "$_codex_config" > "$_codex_config_tmp"
  mv "$_codex_config_tmp" "$_codex_config"
  unset _codex_config_tmp
fi

# tools sync may replace ~/.local/bin/node; re-point at the nvm default after stow.
if declare -F sync_nvm_local_bin_links >/dev/null 2>&1; then
  step "nvm local bin links"
  sync_nvm_local_bin_links
  ok "node links: $(readlink -f "$HOME/.local/bin/node" 2>/dev/null || printf 'updated')"
fi

step "codex telemetry"
if [[ -e "$_codex_config" ]]; then
  _codex_config_target="$(readlink -f "$_codex_config" 2>/dev/null || printf '%s' "$_codex_config")"
  _codex_otel_ca=""
  for _ca in \
    "${OMNI_OTEL_CA_PATH:-}" \
    /etc/ssl/certs/lan-ca.pem \
    "$HOME/.local/share/certs/lan-ca.pem" \
    /usr/local/share/ca-certificates/lan-ca.crt
  do
    if [[ -r "$_ca" ]]; then
      _codex_otel_ca="$_ca"
      break
    fi
  done
  if [[ -n "$_codex_otel_ca" ]]; then
    sed -i -E \
      -e "s|^([[:space:]]*ca-certificate = ).*|\\1\"$_codex_otel_ca\"|" \
      "$_codex_config_target"
    ok "Codex OTEL uses $_codex_otel_ca"
  else
    sed -i \
      -e '/^[[:space:]]*ca-certificate = /d' \
      "$_codex_config_target"
    warn "Codex OTEL CA missing; removed explicit ca-certificate entries"
  fi
  sed -i \
    -e 's|https://api\.ai\.h-cloud\.lan/mcp/|http://litellm-proxy.ai.svc.cluster.local:4000/mcp/|' \
    "$_codex_config_target"
  ok "Codex litellm MCP -> in-cluster service"
  unset _codex_config_target _codex_otel_ca _ca
else
  warn "Codex config not found after dots sync"
fi
unset _codex_config

# Omni MCP restore references this binary; the dotfiles copy is macOS-only.
if [[ ! -x "$HOME/.local/bin/codebase-memory-mcp" ]]; then
  step "codebase-memory-mcp"
  mkdir -p "$HOME/.local/bin"
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

export OMNI_AGENTS_REQUIRED=1
bash "$REPO_DIR/scripts/bootstrap-agents.sh"

_claude_config="$HOME/.claude.json"
if [[ -f "$_claude_config" ]]; then
  step "litellm MCP in-cluster URL (claude)"
  sed -i \
    -e 's|https://api\.ai\.h-cloud\.lan/mcp/|http://litellm-proxy.ai.svc.cluster.local:4000/mcp/|g' \
    "$_claude_config"
  ok "claude litellm MCP -> in-cluster service"
fi
unset _claude_config

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
    unset _repo_dirs _repo _repo_path
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
