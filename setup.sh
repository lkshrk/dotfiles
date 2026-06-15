#!/usr/bin/env bash
# setup.sh - macOS workstation bootstrap for this dotfiles repo.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"
OMNI_MIN_VERSION="0.8.5"
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

ensure_omni_version() {
  local current
  current="$(omni_version)"
  [[ -n "$current" ]] || die "could not determine omni version; update omni and rerun setup"
  version_at_least "$current" "$OMNI_MIN_VERSION" \
    || die "installed omni $current is older than required $OMNI_MIN_VERSION; update omni and rerun setup"
}

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
  ensure_omni_version
  omni bootstrap --help >/dev/null 2>&1 || die "installed omni does not support 'bootstrap'; update omni and rerun setup"
  [[ -f "$OMNI_CONFIG_PATH" ]] || die "Omni config not found: $OMNI_CONFIG_PATH"
  omni --config "$OMNI_CONFIG_PATH" settings show --format json >/dev/null 2>&1 \
    || die "installed omni cannot read this repo's config; update omni and rerun setup"
  ok "$(omni --version 2>/dev/null || printf 'omni found')"
}

omni_bootstrap() {
  step "omni bootstrap"
  omni --config "$OMNI_CONFIG_PATH" --yes bootstrap
}

# ─── Shared: generated shell completions ─────────────────────────────────────

install_zsh_completions() {
  step "zsh completions"

  local completions_dir="$HOME/.cache/zsh/completions"
  mkdir -p "$completions_dir"

  if command -v argo >/dev/null 2>&1; then
    argo completion zsh \
      | sed '/^#compdef argo$/d; /^compdef _argo argo$/d; s/_argo/_argo_upstream/g' \
      > "$completions_dir/_argo_upstream"
    ok "argo completion installed"
  else
    warn "argo is not on PATH; skipping argo completion"
  fi
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
  install_zsh_completions

  install_lefthook

  bash "$REPO_DIR/scripts/bootstrap-agents.sh"
}

main "$@"
