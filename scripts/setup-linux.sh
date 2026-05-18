#!/usr/bin/env bash
# scripts/setup-linux.sh - Linux-specific bootstrap steps.
# Sourced variables from setup.sh: REPO_DIR, OMNI_CONFIG_PATH,
#   c_red/c_yel/c_grn/c_dim/c_off.
# Helper functions (say/step/ok/warn/die) are exported from setup.sh.

set -euo pipefail

[[ "$(uname -s)" == "Linux" ]] || { echo "setup-linux.sh must run on Linux" >&2; return 1; }

# ─── Base packages via apt ────────────────────────────────────────────────────

install_apt_packages() {
  step "apt packages"
  command -v apt-get >/dev/null 2>&1 || {
    warn "apt-get not found; skipping base package install (non-Debian/Ubuntu system?)"
    return
  }

  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends \
    curl \
    git \
    stow \
    jq \
    build-essential \
    ca-certificates \
    unzip
  ok "base apt packages installed"
}

# ─── omni on Linux ────────────────────────────────────────────────────────────
# omni's official install script works on Linux. If it fails or is unavailable,
# we fall back to stowing cross-platform dotfiles directly with GNU stow.

install_omni_linux() {
  step "omni (Linux)"

  if command -v omni >/dev/null 2>&1; then
    ok "omni already on PATH: $(omni --version 2>/dev/null || printf 'found')"
    return
  fi

  # omni is distributed via lkshrk/homebrew-tap. On Linux without Homebrew,
  # try building from source if Go is available, otherwise fall back to stow.
  if command -v brew >/dev/null 2>&1; then
    brew tap lkshrk/tap 2>/dev/null || true
    brew install omni 2>/dev/null || true
  elif command -v go >/dev/null 2>&1; then
    go install github.com/lkshrk/omni@latest 2>/dev/null || true
    export PATH="$HOME/go/bin:$PATH"
  fi

  if command -v omni >/dev/null 2>&1; then
    ok "omni installed: $(omni --version 2>/dev/null || printf 'found')"
  else
    warn "omni not available on this Linux system"
    warn "falling back to direct stow of cross-platform dotfile packages"
    OMNI_AVAILABLE=0
    export OMNI_AVAILABLE
    stow_dotfiles_fallback
  fi
}

# ─── Fallback: stow dots directly ─────────────────────────────────────────────
# Used when omni is unavailable. Stows every top-level package directory that
# lives inside the dotfiles/ subtree (same root omni would manage).

stow_dotfiles_fallback() {
  step "stow dotfiles (fallback)"
  local dots_dir="$REPO_DIR/dotfiles"

  [[ -d "$dots_dir" ]] || {
    warn "dotfiles directory not found at $dots_dir; nothing to stow"
    return
  }

  command -v stow >/dev/null 2>&1 || die "stow is not installed; cannot deploy dotfiles"

  # Cross-platform packages only. Skip macOS-only stuff.
  local -a linux_packages=(
    claude codex git gh nvim tmux vim
    zsh zshrc zshenv zprofile
    opencode skill-lock.json ssh
  )

  local pkg
  for pkg in "${linux_packages[@]}"; do
    [[ -d "$dots_dir/$pkg" ]] || continue
    stow --dir="$dots_dir" --target="$HOME" --restow "$pkg" 2>/dev/null \
      && ok "stowed $pkg" \
      || warn "stow $pkg failed (conflicts?); skipping"
  done
}

# ─── main ─────────────────────────────────────────────────────────────────────

install_apt_packages
install_omni_linux
