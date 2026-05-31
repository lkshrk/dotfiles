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

[[ "$(uname -s)" == "Linux" ]] || die "setup-coder.sh is Linux-only"
[[ -f "$OMNI_CONFIG_PATH" ]] || die "Omni config not found: $OMNI_CONFIG_PATH"

export REPO_DIR OMNI_CONFIG_PATH RUN_MACOS_DEFAULTS SKIP_ADMIN_WARMUP
export c_red c_yel c_grn c_dim c_off

source "$REPO_DIR/scripts/setup-coder-linux.sh"

command -v omni >/dev/null 2>&1 || die "omni is not installed"
omni bootstrap --help >/dev/null 2>&1 || die "installed omni does not support bootstrap"

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
# Coder's codex module writes a real ~/.codex/config.toml at agent start, and the
# oh-my-zsh installer writes a real ~/.zshrc; both collide with the symlinks omni
# wants to stow. Drop them so dots sync links cleanly.
rm -f "$HOME/.codex/config.toml" "$HOME/.zshrc"
omni --config "$OMNI_CONFIG_PATH" --yes dots sync

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
