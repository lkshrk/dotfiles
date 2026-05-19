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

install_omni_linux() {
  step "omni (Linux)"

  if command -v omni >/dev/null 2>&1; then
    ok "omni already on PATH: $(omni --version 2>/dev/null || printf 'found')"
    return
  fi

  # Try: GitHub release binary → brew tap → go install
  OMNI_VERSION=$(curl -s https://api.github.com/repos/lkshrk/Omni/releases/latest | grep tag_name | cut -d '"' -f4 2>/dev/null || true)
  if [[ -n "$OMNI_VERSION" ]]; then
    curl -fsSL "https://github.com/lkshrk/Omni/releases/download/${OMNI_VERSION}/Omni_linux_x86_64.tar.gz" | tar xz -C /tmp omni
    sudo install /tmp/omni /usr/local/bin/omni
    rm -f /tmp/omni
  elif command -v brew >/dev/null 2>&1; then
    brew tap lkshrk/tap 2>/dev/null || true
    brew install omni 2>/dev/null || true
  elif command -v go >/dev/null 2>&1; then
    go install github.com/lkshrk/omni@latest 2>/dev/null || true
    export PATH="$HOME/go/bin:$PATH"
  fi

  if command -v omni >/dev/null 2>&1; then
    ok "omni installed: $(omni --version 2>/dev/null || printf 'found')"
  else
    warn "omni not available on this Linux system — dotfiles won't be managed"
    OMNI_AVAILABLE=0
    export OMNI_AVAILABLE
  fi
}

# ─── main ─────────────────────────────────────────────────────────────────────

install_apt_packages
install_omni_linux
