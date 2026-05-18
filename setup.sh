#!/usr/bin/env bash
# setup.sh - cross-platform bootstrap for this dotfiles repo.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"
RUN_MACOS_DEFAULTS=0
SKIP_ADMIN_WARMUP=0

usage() {
  cat <<'USAGE'
setup.sh - cross-platform bootstrap for this dotfiles repo.

Usage:
  ./setup.sh [--macos-defaults] [--skip-admin-warmup]

Options:
  --macos-defaults      Run scripts/macos-defaults.sh after Omni reconcile (macOS only).
  --skip-admin-warmup   Do not run sudo -v before privileged package actions.
  -h, --help            Show this help.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --macos-defaults) RUN_MACOS_DEFAULTS=1 ;;
    --skip-admin-warmup) SKIP_ADMIN_WARMUP=1 ;;
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

# ─── OS detection ─────────────────────────────────────────────────────────────

OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM=macos ;;
  Linux)  PLATFORM=linux ;;
  *) die "Unsupported OS: $OS" ;;
esac

# ─── Shared: warm admin session ───────────────────────────────────────────────

warm_admin_session() {
  (( SKIP_ADMIN_WARMUP )) && return
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
  say "${c_dim}platform: $PLATFORM${c_off}"

  warm_admin_session

  # Platform-specific script handles: package manager bootstrap, stow + omni
  # install, and any OS-specific steps.
  local platform_script="$REPO_DIR/scripts/setup-${PLATFORM}.sh"
  [[ -f "$platform_script" ]] || die "platform script not found: $platform_script"

  # Export variables the platform scripts need.
  export REPO_DIR OMNI_CONFIG_PATH RUN_MACOS_DEFAULTS SKIP_ADMIN_WARMUP
  export c_red c_yel c_grn c_dim c_off

  source "$platform_script"

  # Omni bootstrap + reconcile run on all platforms (platform script ensures
  # omni is available, or skips this block via OMNI_AVAILABLE=0).
  if [[ "${OMNI_AVAILABLE:-1}" == "1" ]]; then
    ensure_omni_bootstrap
    omni_bootstrap
  fi

  install_lefthook

  bash "$REPO_DIR/scripts/bootstrap-agents.sh"
}

main "$@"
