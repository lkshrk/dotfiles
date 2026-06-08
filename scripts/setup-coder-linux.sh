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
    if omni_version_is_supported && omni --config "$OMNI_CONFIG_PATH" settings show --format json >/dev/null 2>&1; then
      ok "omni already on PATH: $(omni --version 2>/dev/null || printf 'found')"
      return
    fi
    warn "installed omni is older than $OMNI_MIN_VERSION or cannot read this repo's config; installing current release"
  fi

  # The releases/latest/download redirect is served by github.com and is not
  # subject to the 60/hr unauthenticated api.github.com rate limit (which a
  # shared NAT egress IP exhausts and which left omni uninstalled).
  curl -fsSL "https://github.com/lkshrk/Omni/releases/latest/download/Omni_linux_x86_64.tar.gz" | tar xz -C /tmp omni
  sudo install /tmp/omni /usr/local/bin/omni
  rm -f /tmp/omni

  if command -v omni >/dev/null 2>&1 && omni_version_is_supported; then
    ok "omni installed: $(omni --version 2>/dev/null || printf 'found')"
  else
    die "omni $OMNI_MIN_VERSION or newer is required for the Coder profile but could not be installed"
  fi
}

# ─── bun (Linux) ──────────────────────────────────────────────────────────────
#
# Installed up-front, before `omni tools sync`, for two reasons:
#   1. omni's node provider probes `command -v bun`; without it on PATH the whole
#      node ecosystem (yaml-language-server, yaml-lint, …) is skipped.
#   2. Several script-provider installers (codex, devcontainer, …) shell out to
#      "$HOME/.bun/bin/bun add -g", so bun must exist regardless of sync order.

install_bun_linux() {
  step "bun (Linux)"

  if [[ ! -x "$HOME/.bun/bin/bun" ]]; then
    curl -fsSL https://bun.sh/install | bash
  fi

  if [[ -x "$HOME/.bun/bin/bun" ]]; then
    ok "bun ready: $("$HOME/.bun/bin/bun" --version 2>/dev/null || printf 'found')"
  else
    warn "bun install failed; node ecosystem and bun-based tools will be skipped"
  fi
}

# ─── PATH for the sync session ────────────────────────────────────────────────
#
# This file is *sourced* by setup-coder.sh, so exporting PATH here makes the
# freshly installed binaries (and bun) visible to the omni bootstrap/sync steps
# that follow, before the login shell's zsh PATH config is in effect.

export_sync_path() {
  export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.krew/bin:$HOME/.cargo/bin:$PATH"
}

# ─── main ─────────────────────────────────────────────────────────────────────

install_apt_packages
install_omni_linux
install_bun_linux
export_sync_path
