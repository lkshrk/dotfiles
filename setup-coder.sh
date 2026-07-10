#!/usr/bin/env bash
# setup-coder.sh - bootstrap a Coder workspace through the Coder Omni profile.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"
OMNI_MIN_VERSION="0.8.5"
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

omni_version_is_supported() {
  local current
  current="$(omni_version)"
  [[ -n "$current" ]] && version_at_least "$current" "$OMNI_MIN_VERSION"
}

ensure_omni_version() {
  local current
  current="$(omni_version)"
  [[ -n "$current" ]] || die "could not determine omni version"
  version_at_least "$current" "$OMNI_MIN_VERSION" \
    || die "installed omni $current is older than required $OMNI_MIN_VERSION"
}

[[ "$(uname -s)" == "Linux" ]] || die "setup-coder.sh is Linux-only"
[[ -f "$OMNI_CONFIG_PATH" ]] || die "Omni config not found: $OMNI_CONFIG_PATH"

export REPO_DIR OMNI_CONFIG_PATH RUN_MACOS_DEFAULTS SKIP_ADMIN_WARMUP
export c_red c_yel c_grn c_dim c_off

source "$REPO_DIR/scripts/setup-coder-linux.sh"

command -v omni >/dev/null 2>&1 || die "omni is not installed"
ensure_omni_version
omni bootstrap --help >/dev/null 2>&1 || die "installed omni does not support bootstrap"
omni --config "$OMNI_CONFIG_PATH" settings show --format json >/dev/null 2>&1 \
  || die "installed omni cannot read this repo's config"

export OMNI_HOSTNAME="$CODER_OMNI_HOST"
export DOTFILES_DIR="${DOTFILES_DIR:-$REPO_DIR}"

step "omni coder profile"
ok "using Omni host profile: $OMNI_HOSTNAME"

step "omni bootstrap"
omni --config "$OMNI_CONFIG_PATH" --yes bootstrap --no-import

step "omni tools"
omni --config "$OMNI_CONFIG_PATH" --yes tools sync --all

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
# Coder's codex module writes a real ~/.codex/config.toml at agent start, the
# oh-my-zsh installer writes a real ~/.zshrc, opencode replaces its config
# symlinks with real files at runtime, and Claude Code rewrites
# .claude/plugins/installed_plugins.json; all collide with the symlinks omni
# wants to stow (--use-repo does not resolve a replaced-symlink conflict).
# Drop them so dots sync links cleanly.
rm -f "$HOME/.codex/config.toml" "$HOME/.zshrc" \
  "$HOME/.claude/plugins/installed_plugins.json"
rm -rf "$HOME/.config/opencode"
omni --config "$OMNI_CONFIG_PATH" --yes dots sync --use-repo

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

# Prewarm nvim plugins headlessly so the first interactive launch is instant.
# Needs both the binary (tools sync) and the stowed config (dots sync above).
if command -v nvim >/dev/null 2>&1 || [ -x "$HOME/.local/bin/nvim" ]; then
  step "nvim plugins"
  PATH="$HOME/.local/bin:$PATH" nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 \
    || PATH="$HOME/.local/bin:$PATH" nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 \
    || warn "nvim plugin sync failed; plugins will install on first launch"
fi

# Make zsh the login shell now that the binary is installed (core group).
if command -v zsh >/dev/null 2>&1; then
  _zsh_path="$(command -v zsh)"
  grep -qx "$_zsh_path" /etc/shells 2>/dev/null || echo "$_zsh_path" | sudo tee -a /etc/shells >/dev/null
  if [[ "${SHELL:-}" != "$_zsh_path" ]]; then
    step "login shell -> zsh"
    sudo chsh -s "$_zsh_path" "$USER" || warn "chsh to zsh failed; set login shell manually"
  fi
  unset _zsh_path
fi

bash "$REPO_DIR/scripts/bootstrap-agents.sh"
