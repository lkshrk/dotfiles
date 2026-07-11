#!/usr/bin/env bash
# scripts/setup-coder-linux.sh - minimal Linux prerequisites for Coder.
# Sourced variables from setup-coder.sh: REPO_DIR, OMNI_CONFIG_PATH,
#   c_red/c_yel/c_grn/c_dim/c_off.
# Helper functions (say/step/ok/warn/die) are exported from setup-coder.sh.

set -euo pipefail

[[ "$(uname -s)" == "Linux" ]] || { echo "setup-coder-linux.sh must run on Linux" >&2; return 1; }

# omni's installer and uv land binaries in ~/.local/bin; the Coder agent's
# non-login shell does not have it on PATH.
export PATH="$HOME/.local/bin:$PATH"

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
    unzip \
    zsh
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
  curl -fsSL https://raw.githubusercontent.com/lkshrk/omni/main/scripts/linux-install.sh | bash

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

# ─── nvm + Node (Linux) ──────────────────────────────────────────────────────

install_nvm_node_linux() {
  step "nvm + Node 24 (Linux)"

  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi

  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh" --no-use
  fi

  if ! command -v nvm >/dev/null 2>&1; then
    die "nvm is required for the Coder Node profile but could not be installed"
  fi

  nvm install 24 --latest-npm
  nvm alias default 24
  nvm use --silent default

  # Agent-spawned shells never source profile.sh, so without these links they
  # fall back to the system node (v18, too old for pnpm and friends).
  if [[ -n "${NVM_BIN:-}" ]]; then
    mkdir -p "$HOME/.local/bin"
    local bin
    for bin in node npm npx corepack; do
      [[ -x "$NVM_BIN/$bin" ]] && ln -sf "$NVM_BIN/$bin" "$HOME/.local/bin/$bin"
    done
  fi

  ok "node ready: $(node --version 2>/dev/null || printf 'found')"
}

# ─── grok (Linux) ─────────────────────────────────────────────────────────────
#
# Omni's agents restore targets grok for plugins/MCP; install the CLI before
# agents restore. Lands in ~/.grok/bin (added to PATH in export_sync_path).

install_grok_linux() {
  step "grok (Linux)"

  if command -v grok >/dev/null 2>&1 || [[ -x "$HOME/.grok/bin/grok" ]]; then
    ok "grok ready: $(grok --version 2>/dev/null | head -n1 || printf 'found')"
    return
  fi

  curl -fsSL https://x.ai/cli/install.sh | bash

  if command -v grok >/dev/null 2>&1 || [[ -x "$HOME/.grok/bin/grok" ]]; then
    ok "grok installed: $(grok --version 2>/dev/null | head -n1 || printf 'found')"
  else
    warn "grok install failed; grok plugins/MCP restore will be skipped"
  fi
}

# ─── uv (Linux) ───────────────────────────────────────────────────────────────
#
# omni's uv provider (thefuck, …) probes for `uv`; install it before sync.
# Lands in ~/.local/bin (already on PATH, no sudo needed).

install_uv_linux() {
  step "uv (Linux)"

  if ! command -v uv >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/uv" ]]; then
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$HOME/.local/bin" sh
  fi

  if command -v uv >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/uv" ]]; then
    ok "uv ready: $(uv --version 2>/dev/null || "$HOME/.local/bin/uv" --version 2>/dev/null || printf 'found')"
  else
    warn "uv install failed; uv-based tools (thefuck) will be skipped"
  fi
}

# ─── PATH for the sync session ────────────────────────────────────────────────
#
# This file is *sourced* by setup-coder.sh, so exporting PATH here makes the
# freshly installed binaries (and bun) visible to the omni bootstrap/sync steps
# that follow, before the login shell's zsh PATH config is in effect.

export_sync_path() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh" --no-use
    nvm use --silent default >/dev/null 2>&1 || true
  fi

  # pnpm errors on `pnpm ls -g` when its global bin dir is off PATH, which
  # aborts omni's bulk status check and with it the whole tools sync.
  export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
  mkdir -p "$PNPM_HOME/bin"

  export PATH="${NVM_BIN:+$NVM_BIN:}$PNPM_HOME/bin:$HOME/.grok/bin:$HOME/.local/bin:$HOME/.bun/bin:$HOME/.krew/bin:$HOME/.cargo/bin:$PATH"
}

# ─── main ─────────────────────────────────────────────────────────────────────

install_apt_packages
install_omni_linux
install_bun_linux
install_nvm_node_linux
install_grok_linux
install_uv_linux
export_sync_path
