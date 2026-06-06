#!/usr/bin/env bash
# scripts/setup-macos.sh - macOS-specific bootstrap steps.
# Sourced variables from setup.sh: REPO_DIR, OMNI_CONFIG_PATH,
#   RUN_MACOS_DEFAULTS, c_red/c_yel/c_grn/c_dim/c_off.
# Helper functions (say/step/ok/warn/die) are exported from setup.sh.

set -euo pipefail

[[ "$(uname -s)" == "Darwin" ]] || { echo "setup-macos.sh must run on macOS" >&2; return 1; }

# ─── Xcode Command Line Tools ─────────────────────────────────────────────────

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

# ─── Homebrew ─────────────────────────────────────────────────────────────────

load_brew_shellenv() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
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

# ─── sleep-on-lock ────────────────────────────────────────────────────────────

compile_sleep_on_lock() {
  step "sleep-on-lock"
  local src="$HOME/.config/yabai/sleep-on-lock.swift"
  local bin="$HOME/.local/bin/sleep-on-lock"
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

# ─── yabai sudoers ────────────────────────────────────────────────────────────

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

# ─── macOS defaults ───────────────────────────────────────────────────────────

run_macos_defaults() {
  (( RUN_MACOS_DEFAULTS )) || return
  step "macos defaults"
  bash "$REPO_DIR/scripts/macos-defaults.sh"
  ok "macOS defaults applied"
}

# ─── main ─────────────────────────────────────────────────────────────────────

ensure_command_line_tools
ensure_homebrew
install_bootstrap_tools
compile_sleep_on_lock
install_sleep_on_lock_agent
refresh_yabai_sudoers
run_macos_defaults
