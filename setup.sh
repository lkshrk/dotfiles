#!/usr/bin/env bash
# setup.sh - macOS workstation bootstrap for this dotfiles repo.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"
RUN_MACOS_DEFAULTS=0

usage() {
  cat <<'USAGE'
setup.sh - macOS workstation bootstrap for this dotfiles repo.

Usage:
  ./setup.sh [--macos-defaults]

Options:
  --macos-defaults      Run scripts/macos-defaults.sh after Omni bootstrap.
  -h, --help            Show this help.

Coder/Linux workspaces use ./setup-coder.sh.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --macos-defaults) RUN_MACOS_DEFAULTS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

# ─── Colour helpers ────────────────────────────────────────────────────────────

c_red=$'\033[31m'
c_yel=$'\033[33m'
c_grn=$'\033[32m'
c_dim=$'\033[2m'
c_off=$'\033[0m'

say()  { printf '%s\n' "$*"; }
step() { say "${c_dim}-- $* --${c_off}"; }
ok()   { say "${c_grn}ok${c_off} $*"; }
warn() { say "${c_yel}!${c_off} $*" >&2; }
die()  { say "${c_red}x${c_off} $*" >&2; exit 1; }

export -f say step ok warn die

# ─── OS guard ─────────────────────────────────────────────────────────────────

OS="$(uname -s)"
[[ "$OS" == "Darwin" ]] || die "setup.sh is macOS-only; use ./setup-coder.sh for Coder/Linux workspaces"

# ─── Shared: warm admin session ───────────────────────────────────────────────

warm_admin_session() {
  [[ -t 0 && -t 1 ]] || {
    warn "non-interactive terminal; privileged package installs may fail if authentication is required"
    return
  }

  step "admin session"
  sudo -v
  ok "sudo credentials cached for this terminal"
}

# ─── Shared: omni bootstrap + reconcile ───────────────────────────────────────

ensure_omni_bootstrap() {
  step "omni"
  command -v omni >/dev/null 2>&1 || die "omni is not installed"
  omni bootstrap --help >/dev/null 2>&1 || die "installed omni does not support 'bootstrap'; update omni and rerun setup"
  [[ -f "$OMNI_CONFIG_PATH" ]] || die "Omni config not found: $OMNI_CONFIG_PATH"
  ok "$(omni --version 2>/dev/null || printf 'omni found')"
}

omni_bootstrap() {
  step "omni bootstrap"
  omni --config "$OMNI_CONFIG_PATH" --yes bootstrap
}

# ─── Shared: lefthook ─────────────────────────────────────────────────────────

install_lefthook() {
  step "lefthook"
  if command -v lefthook >/dev/null 2>&1; then
    (cd "$REPO_DIR" && lefthook install)
    ok "lefthook installed"
  else
    warn "lefthook is not installed; Omni reconcile should install it through the dev group"
  fi
}

# ─── main ─────────────────────────────────────────────────────────────────────

main() {
  say "${c_dim}platform: macos${c_off}"

  warm_admin_session

  local platform_script="$REPO_DIR/scripts/setup-macos.sh"
  [[ -f "$platform_script" ]] || die "platform script not found: $platform_script"

  # Export variables the platform script needs.
  export REPO_DIR OMNI_CONFIG_PATH RUN_MACOS_DEFAULTS
  export c_red c_yel c_grn c_dim c_off

  source "$platform_script"

  ensure_omni_bootstrap
  omni_bootstrap

  install_lefthook

  bash "$REPO_DIR/scripts/bootstrap-agents.sh"
}

main "$@"
