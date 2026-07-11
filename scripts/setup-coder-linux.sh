#!/usr/bin/env bash
# scripts/setup-coder-linux.sh - minimal Linux bootstrap before omni can run.
# Sourced variables from setup-coder.sh: REPO_DIR, OMNI_CONFIG_PATH,
#   c_red/c_yel/c_grn/c_dim/c_off.
# Helper functions (say/step/ok/warn/die) are exported from setup-coder.sh.

set -euo pipefail

[[ "$(uname -s)" == "Linux" ]] || { echo "setup-coder-linux.sh must run on Linux" >&2; return 1; }

# omni lands binaries in ~/.local/bin; Coder agent shells often start without it.
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

# ─── Login shell (Linux) ───────────────────────────────────────────────────────

activate_zsh_login_shell() {
  command -v zsh >/dev/null 2>&1 || return 0

  local zsh_path
  zsh_path="$(command -v zsh)"
  grep -qx "$zsh_path" /etc/shells 2>/dev/null || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  if [[ "${SHELL:-}" != "$zsh_path" ]]; then
    step "login shell -> zsh"
    sudo chsh -s "$zsh_path" "$USER" || warn "chsh to zsh failed; set login shell manually"
  else
    ok "login shell already zsh"
  fi
}

# ─── Omni on Linux (chicken-and-egg) ──────────────────────────────────────────

omni_reads_config() {
  command -v omni >/dev/null 2>&1 \
    && omni --config "$OMNI_CONFIG_PATH" settings show --format json >/dev/null 2>&1
}

install_omni_linux() {
  step "omni (Linux)"

  if omni_reads_config; then
    ok "omni already on PATH: $(omni --version 2>/dev/null || printf 'found')"
    return
  fi

  if command -v omni >/dev/null 2>&1; then
    warn "installed omni cannot read this repo's config; installing latest release"
  fi

  bash "$REPO_DIR/scripts/install-omni-latest.sh"

  if omni_reads_config; then
    ok "omni installed: $(omni --version 2>/dev/null || printf 'found')"
  else
    die "latest omni could not read $OMNI_CONFIG_PATH"
  fi
}

# ─── nvm symlinks for agent shells ────────────────────────────────────────────
#
# Agent subshells never source zshenv; keep node on PATH via ~/.local/bin.

sync_nvm_local_bin_links() {
  local nvm_node_bin="${1:-}"
  local env_nvm_lib="${REPO_DIR}/dotfiles/env/.config/env/lib/nvm-node.sh"

  if [[ -z "$nvm_node_bin" && -r "$env_nvm_lib" ]]; then
    # shellcheck source=/dev/null
    . "$env_nvm_lib"
    nvm_node_bin="$(env_next_nvm_resolve_bin default 2>/dev/null || true)"
    unset -f env_next_nvm_alias_target env_next_nvm_best_dir_from_candidates 2>/dev/null || true
    unset -f env_next_nvm_resolve_dir env_next_nvm_resolve_bin 2>/dev/null || true
  fi

  if [[ -z "$nvm_node_bin" && -n "${NVM_BIN:-}" ]]; then
    nvm_node_bin="$NVM_BIN"
  fi

  [[ -n "$nvm_node_bin" && -x "$nvm_node_bin/node" ]] || return 0

  mkdir -p "$HOME/.local/bin"
  local bin
  for bin in node npm npx corepack; do
    [[ -x "$nvm_node_bin/$bin" ]] && ln -sf "$nvm_node_bin/$bin" "$HOME/.local/bin/$bin"
  done
}

# ─── PATH for the bootstrap bash session ──────────────────────────────────────

export_sync_path() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh" --no-use
    nvm use --silent default >/dev/null 2>&1 || true
  fi

  export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
  mkdir -p "$PNPM_HOME/bin"

  export PATH="${NVM_BIN:+$NVM_BIN:}$PNPM_HOME/bin:$HOME/.grok/bin:$HOME/.local/bin:$HOME/.bun/bin:$HOME/.krew/bin:$HOME/.cargo/bin:$PATH"
}

# ─── main (phase 1: only what omni cannot do for itself) ─────────────────────

install_apt_packages
activate_zsh_login_shell
install_omni_linux