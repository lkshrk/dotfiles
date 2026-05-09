#!/usr/bin/env bash
# setup.sh - bootstrap this macOS dotfiles repo through Omni.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"
RUN_MACOS_DEFAULTS=0
SKIP_ADMIN_WARMUP=0

usage() {
  cat <<'USAGE'
setup.sh - bootstrap this macOS dotfiles repo through Omni.

Usage:
  ./setup.sh [--macos-defaults] [--skip-admin-warmup]

Options:
  --macos-defaults      Run scripts/macos-defaults.sh after Omni reconcile.
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

c_red=$'\033[31m'
c_yel=$'\033[33m'
c_grn=$'\033[32m'
c_dim=$'\033[2m'
c_off=$'\033[0m'

say() { printf '%s\n' "$*"; }
step() { say "${c_dim}-- $* --${c_off}"; }
ok() { say "${c_grn}ok${c_off} $*"; }
warn() { say "${c_yel}!${c_off} $*" >&2; }
die() { say "${c_red}x${c_off} $*" >&2; exit 1; }

load_brew_shellenv() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "setup.sh currently supports macOS only"
}

ensure_command_line_tools() {
  step "xcode command line tools"
  if xcode-select -p >/dev/null 2>&1 && xcrun --find swiftc >/dev/null 2>&1; then
    ok "command line tools available"
    return
  fi

  if ! xcode-select -p >/dev/null 2>&1; then
    warn "Xcode Command Line Tools are not installed."
    xcode-select --install || true
  fi

  cat >&2 <<'EOF'
Install the Xcode Command Line Tools from the system prompt, then rerun:
  ./setup.sh
EOF
  exit 1
}

ensure_homebrew() {
  step "homebrew"
  load_brew_shellenv
  if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew_shellenv
  fi
  command -v brew >/dev/null 2>&1 || die "Homebrew install did not put brew on PATH"
  ok "$(brew --version | head -n 1)"
}

install_bootstrap_tools() {
  step "bootstrap packages"
  brew install stow omni bun uv
  ok "stow, omni, bun, uv installed"
}

ensure_omni_bootstrap() {
  step "omni"
  command -v omni >/dev/null 2>&1 || die "omni is not installed"
  omni bootstrap --help >/dev/null 2>&1 || die "installed omni does not support 'bootstrap'; update the Homebrew omni formula and rerun setup"
  omni reconcile --help >/dev/null 2>&1 || die "installed omni does not support 'reconcile'; update the Homebrew omni formula and rerun setup"
  [[ -f "$OMNI_CONFIG_PATH" ]] || die "Omni config not found: $OMNI_CONFIG_PATH"
  ok "$(omni --version 2>/dev/null || printf 'omni found')"
}

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

omni_bootstrap_and_reconcile() {
  step "omni bootstrap"
  omni --config "$OMNI_CONFIG_PATH" --yes bootstrap

  step "omni reconcile"
  omni --config "$OMNI_CONFIG_PATH" --yes reconcile
}

compile_sleep_on_lock() {
  step "sleep-on-lock"
  local src="$HOME/.config/yabai/sleep-on-lock.swift"
  local bin="$HOME/.config/yabai/sleep-on-lock"
  local module_cache="${CLANG_MODULE_CACHE_PATH:-$HOME/.cache/clang/ModuleCache}"

  [[ -f "$src" ]] || {
    warn "missing $src; run 'omni --config \"$OMNI_CONFIG_PATH\" dots sync yabai' and rerun setup"
    return
  }
  command -v swiftc >/dev/null 2>&1 || die "swiftc is missing after Command Line Tools install"

  mkdir -p "$(dirname "$bin")" "$module_cache"
  CLANG_MODULE_CACHE_PATH="$module_cache" swiftc -O -o "$bin" "$src" -framework Cocoa
  chmod +x "$bin"
  ok "compiled $bin"
}

install_sleep_on_lock_agent() {
  step "sleep-on-lock launchagent"
  local agent="$HOME/Library/LaunchAgents/com.lkshrk.sleep-on-lock.plist"
  local service="gui/$UID/com.lkshrk.sleep-on-lock"

  [[ -f "$agent" ]] || {
    warn "missing $agent; run 'omni --config \"$OMNI_CONFIG_PATH\" dots sync sleep-on-lock' and rerun setup"
    return
  }

  launchctl bootout "$service" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$UID" "$agent"
  launchctl enable "$service"
  launchctl kickstart -k "$service"
  ok "loaded com.lkshrk.sleep-on-lock"
}

refresh_yabai_sudoers() {
  step "yabai sudoers"
  local script="$HOME/.config/yabai/update_sudoers.sh"

  if ! command -v yabai >/dev/null 2>&1; then
    warn "yabai is not on PATH; skipping sudoers refresh"
    return
  fi
  [[ -x "$script" ]] || {
    warn "missing executable $script; skipping sudoers refresh"
    return
  }

  "$script"
  ok "yabai sudoers entry current"
}

install_lefthook() {
  step "lefthook"
  if command -v lefthook >/dev/null 2>&1; then
    (cd "$REPO_DIR" && lefthook install)
    ok "lefthook installed"
  else
    warn "lefthook is not installed; Omni reconcile should install it through the dev group"
  fi
}

run_macos_defaults() {
  (( RUN_MACOS_DEFAULTS )) || return
  step "macos defaults"
  bash "$REPO_DIR/scripts/macos-defaults.sh"
  ok "macOS defaults applied"
}

main() {
  ensure_macos
  ensure_command_line_tools
  ensure_homebrew
  install_bootstrap_tools
  ensure_omni_bootstrap
  warm_admin_session
  omni_bootstrap_and_reconcile
  compile_sleep_on_lock
  install_sleep_on_lock_agent
  refresh_yabai_sudoers
  install_lefthook
  run_macos_defaults

  cat <<'EOF'

Setup complete.

Recommended next check:
  claude doctor
EOF
}

main "$@"
