#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_MACOS_DEFAULTS=0

usage() {
  cat <<'USAGE'
setup.sh - macOS workstation bootstrap for this dotfiles repo.

Usage:
  ./setup.sh [--macos-defaults]

Options:
  --macos-defaults      Run scripts/macos-defaults.sh during setup.
  -h, --help            Show this help.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --macos-defaults) RUN_MACOS_DEFAULTS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

. "$REPO_DIR/scripts/lib/setup-common.sh"

export -f say step ok warn die

OS="$(uname -s)"
[[ "$OS" == "Darwin" ]] || die "setup.sh is macOS-only"

warm_admin_session() {
  [[ -t 0 && -t 1 ]] || {
    warn "non-interactive terminal; privileged package installs may fail if authentication is required"
    return
  }

  step "admin session"
  sudo -v
  ok "sudo credentials cached for this terminal"
}

install_zsh_completions() {
  step "zsh completions"

  local completions_dir="$HOME/.cache/zsh/completions"
  mkdir -p "$completions_dir"

  if have argo; then
    argo completion zsh \
      | sed '/^#compdef argo$/d; /^compdef _argo argo$/d; s/_argo/_argo_upstream/g' \
      > "$completions_dir/_argo_upstream"
    ok "argo completion installed"
  else
    warn "argo is not on PATH; skipping argo completion"
  fi
}

configure_rbw() {
  step "rbw"
  have rbw || { warn "rbw is not installed; skipping rbw config"; return; }
  rbw_unlock_with_lan_ca || warn "rbw is locked; skipping the LAN root CA"
}

setup_lefthook() {
  step "lefthook"
  if have lefthook; then
    install_lefthook "$REPO_DIR"
  else
    warn "lefthook is not installed; it comes from mise (dev group)"
  fi
}

main() {
  say "${c_dim}platform: macos${c_off}"

  warm_admin_session

  local platform_script="$REPO_DIR/scripts/setup-macos.sh"
  [[ -f "$platform_script" ]] || die "platform script not found: $platform_script"

  export REPO_DIR RUN_MACOS_DEFAULTS
  export c_red c_yel c_grn c_dim c_off

  source "$platform_script"

  chezmoi_apply
  install_zsh_completions
  configure_rbw

  setup_lefthook
}

main "$@"
