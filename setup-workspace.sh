#!/usr/bin/env bash
# setup-workspace.sh - shared Linux workspace bootstrap through an Omni host profile.

set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
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

run_optional() {
  local label="$1"
  shift
  local status
  if "$@"; then
    return 0
  else
    status=$?
  fi
  warn "$label failed (exit $status); continuing setup"
  return 0
}

export -f say step ok warn die

workspace_after_linux() { :; }
workspace_before_dots() { :; }
workspace_after_dots() { :; }
workspace_after_setup() { :; }

setup_workspace_prepare() {
  local host="$1"
  [[ -n "$host" ]] || die "workspace host profile is required"
  [[ "$(uname -s)" == "Linux" ]] || die "setup-workspace.sh is Linux-only"
  [[ -f "$OMNI_CONFIG_PATH" ]] || die "Omni config not found: $OMNI_CONFIG_PATH"

  export REPO_DIR OMNI_CONFIG_PATH
  export c_red c_yel c_grn c_dim c_off

  source "$REPO_DIR/scripts/setup-workspace-linux.sh"
  workspace_after_linux
  install_ghostty_terminfo

  step "omni install"
  bash "$REPO_DIR/scripts/install-omni-latest.sh"
  omni --config "$OMNI_CONFIG_PATH" settings show --format json >/dev/null 2>&1 \
    || die "installed omni cannot read this repo's config"

  export OMNI_HOSTNAME="$host"
  step "omni $host profile"
  ok "using Omni host profile: $OMNI_HOSTNAME"
}

setup_workspace_sync_shell() {
  step "shell (zsh + oh-my-zsh)"
  rm -f "$HOME/.zshrc"
  run_optional "shell tool sync" omni --config "$OMNI_CONFIG_PATH" --yes tools sync shell
  rm -f "$HOME/.zshrc"
  local dot
  for dot in zshenv zshrc zsh env; do
    run_optional "shell dotfiles: $dot" omni --config "$OMNI_CONFIG_PATH" --yes dots sync --use-repo "$dot"
  done
  ok "shell ready: $(command -v zsh 2>/dev/null || printf 'zsh')"
}

setup_workspace_sync_tools() {
  step "toolchain prerequisites"
  run_optional "toolchain prerequisites" omni --config "$OMNI_CONFIG_PATH" --yes tools sync prereqs
  export_sync_path

  step "omni tools"
  run_optional "omni tools" omni --config "$OMNI_CONFIG_PATH" --yes tools sync --all

  if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi

  if [[ -n "${WORKSPACE_OMNI_STACKS:-}" ]]; then
    local stack
    local -a stacks
    IFS=',' read -r -a stacks <<< "$WORKSPACE_OMNI_STACKS"
    for stack in "${stacks[@]}"; do
      stack="${stack//[[:space:]]/}"
      [[ -n "$stack" ]] || continue
      step "omni stack: $stack"
      run_optional "omni stack: $stack" omni --config "$OMNI_CONFIG_PATH" --yes tools sync "$stack"
    done
  fi
}

setup_workspace_sync_dots() {
  step "omni dotfiles"
  rm -f "$HOME/.zshrc"
  workspace_before_dots
  run_optional "omni dotfiles" omni --config "$OMNI_CONFIG_PATH" --yes dots sync --use-repo
  workspace_after_dots
}

setup_workspace_finish() {
  workspace_after_setup

  if command -v nvim >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/nvim" ]]; then
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
}

setup_workspace_main() {
  setup_workspace_prepare "$1"
  setup_workspace_sync_shell
  setup_workspace_sync_tools
  setup_workspace_sync_dots
  setup_workspace_finish
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  [[ $# == 1 ]] || die "usage: ./setup-workspace.sh <omni-host-profile>"
  setup_workspace_main "$1"
fi
