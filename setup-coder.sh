#!/usr/bin/env bash
# setup-coder.sh - bootstrap a Coder workspace through the Coder Omni profile.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"
OMNI_MIN_VERSION="0.8.8"
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

ensure_omni_version() {
  omni_reads_config || die "omni cannot read $OMNI_CONFIG_PATH; install latest omni and rerun setup"
}

[[ "$(uname -s)" == "Linux" ]] || die "setup-coder.sh is Linux-only"
[[ -f "$OMNI_CONFIG_PATH" ]] || die "Omni config not found: $OMNI_CONFIG_PATH"

export REPO_DIR OMNI_CONFIG_PATH RUN_MACOS_DEFAULTS SKIP_ADMIN_WARMUP
export c_red c_yel c_grn c_dim c_off

source "$REPO_DIR/scripts/setup-coder-linux.sh"

command -v omni >/dev/null 2>&1 || die "omni is not installed"
ensure_omni_version
omni --config "$OMNI_CONFIG_PATH" settings show --format json >/dev/null 2>&1 \
  || die "installed omni cannot read this repo's config"

export OMNI_HOSTNAME="$CODER_OMNI_HOST"
export DOTFILES_DIR="${DOTFILES_DIR:-$REPO_DIR}"

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

# tools sync may replace ~/.local/bin/node; re-point at the nvm default after stow.
if declare -F sync_nvm_local_bin_links >/dev/null 2>&1; then
  step "nvm local bin links"
  sync_nvm_local_bin_links
  ok "node links: $(readlink -f "$HOME/.local/bin/node" 2>/dev/null || printf 'updated')"
fi

step "codex telemetry"
_codex_config="$HOME/.codex/config.toml"
if [[ -e "$_codex_config" ]]; then
  _codex_config_target="$(readlink -f "$_codex_config" 2>/dev/null || printf '%s' "$_codex_config")"
  _codex_otel_ca=""
  for _ca in \
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
      -e 's#^notify = .*#notify = []#' \
      "$_codex_config_target"
    ok "Codex OTEL uses $_codex_otel_ca"
  else
    sed -i \
      -e '/^[[:space:]]*ca-certificate = /d' \
      -e 's#^notify = .*#notify = []#' \
      "$_codex_config_target"
    warn "Codex OTEL CA missing; removed explicit ca-certificate entries"
  fi
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
    *)
      asset=codebase-memory-mcp-linux-amd64.tar.gz
      ;;
  esac
  curl -fsSL "https://github.com/DeusData/codebase-memory-mcp/releases/latest/download/$asset" \
    | tar -xz -C "$HOME/.local/bin" codebase-memory-mcp \
    || warn "codebase-memory-mcp install failed; omni MCP restore may skip it"
fi

export OMNI_AGENTS_REQUIRED=1 OMNI_MIN_VERSION
bash "$REPO_DIR/scripts/bootstrap-agents.sh"

step "grok auth"
_grok_auth="$HOME/.grok/auth.json"
if [[ -n "${GROK_AUTH_JSON:-}" ]] && [[ ! -s "$_grok_auth" ]]; then
  mkdir -p "$HOME/.grok"
  printf '%s' "$GROK_AUTH_JSON" > "$_grok_auth"
  chmod 600 "$_grok_auth"
  ok "seeded grok auth from GROK_AUTH_JSON"
elif [[ -n "${XAI_API_KEY:-}" ]]; then
  ok "XAI_API_KEY available for grok"
elif [[ -s "$_grok_auth" ]]; then
  ok "grok auth already present"
else
  warn "no grok auth; set GROK_AUTH_JSON, XAI_API_KEY, or run: grok login --device-auth"
fi
unset _grok_auth

# Prewarm nvim plugins headlessly so the first interactive launch is instant.
# Needs both the binary (tools sync) and the stowed config (dots sync above).
if command -v nvim >/dev/null 2>&1 || [ -x "$HOME/.local/bin/nvim" ]; then
  step "nvim plugins"
  PATH="$HOME/.local/bin:$PATH" nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 \
    || PATH="$HOME/.local/bin:$PATH" nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 \
    || warn "nvim plugin sync failed; plugins will install on first launch"
fi

activate_zsh_login_shell
