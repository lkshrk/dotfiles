#!/usr/bin/env bash
# scripts/setup-coder-linux.sh - minimal Linux prerequisites for Coder.
# Sourced variables from setup-coder.sh: REPO_DIR, OMNI_CONFIG_PATH,
#   c_red/c_yel/c_grn/c_dim/c_off.
# Helper functions (say/step/ok/warn/die) are exported from setup-coder.sh.

set -euo pipefail

[[ "$(uname -s)" == "Linux" ]] || { echo "setup-coder-linux.sh must run on Linux" >&2; return 1; }

# ─── Coder base packages via apt ──────────────────────────────────────────────

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

# ─── Omni on Linux ────────────────────────────────────────────────────────────

install_omni_linux() {
  step "omni (Linux)"

  if command -v omni >/dev/null 2>&1; then
    ok "omni already on PATH: $(omni --version 2>/dev/null || printf 'found')"
    return
  fi

  OMNI_VERSION=$(curl -s https://api.github.com/repos/lkshrk/Omni/releases/latest | grep tag_name | cut -d '"' -f4 2>/dev/null || true)
  if [[ -n "$OMNI_VERSION" ]]; then
    curl -fsSL "https://github.com/lkshrk/Omni/releases/download/${OMNI_VERSION}/Omni_linux_x86_64.tar.gz" | tar xz -C /tmp omni
    sudo install /tmp/omni /usr/local/bin/omni
    rm -f /tmp/omni
  fi

  if command -v omni >/dev/null 2>&1; then
    ok "omni installed: $(omni --version 2>/dev/null || printf 'found')"
  else
    die "omni is required for the Coder profile but could not be installed"
  fi
}

# ─── main ─────────────────────────────────────────────────────────────────────

install_apt_packages
install_omni_linux
