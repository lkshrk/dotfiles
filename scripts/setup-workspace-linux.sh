#!/usr/bin/env bash
# scripts/setup-workspace-linux.sh - shared Linux prerequisites before Omni runs.

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    warn "root privileges required: $*"
    return 1
  fi
}

install_apt_packages() {
  step "apt packages"
  command -v apt-get >/dev/null 2>&1 || {
    warn "apt-get not found; skipping base package install (non-Debian/Ubuntu system?)"
    return
  }

  run_as_root apt-get update -qq || {
    warn "apt package index update failed; continuing setup"
    return 0
  }
  run_as_root apt-get install -y --no-install-recommends \
    curl \
    git \
    stow \
    jq \
    build-essential \
    ca-certificates \
    openssl \
    ncurses-bin \
    pkg-config \
    libssl-dev \
    unzip \
    xz-utils \
    zsh || {
      warn "base apt package install failed; continuing setup"
      return 0
    }
  ok "base apt packages installed"
}

install_ghostty_terminfo() {
  step "Ghostty terminfo"
  if infocmp -x xterm-ghostty >/dev/null 2>&1; then
    ok "Ghostty terminfo already installed"
    return 0
  fi

  local source="$REPO_DIR/assets/terminfo/xterm-ghostty.terminfo"
  [[ -r "$source" ]] || {
    warn "Ghostty terminfo source missing; continuing setup"
    return 0
  }
  command -v tic >/dev/null 2>&1 || {
    warn "tic not found; continuing setup"
    return 0
  }

  mkdir -p "$HOME/.terminfo"
  tic -x -o "$HOME/.terminfo" "$source" >/dev/null 2>&1 || {
    warn "Ghostty terminfo install failed; continuing setup"
    return 0
  }
  TERMINFO="$HOME/.terminfo" infocmp -x xterm-ghostty >/dev/null 2>&1 || {
    warn "Ghostty terminfo verification failed; continuing setup"
    return 0
  }
  ok "Ghostty terminfo installed"
}

activate_zsh_login_shell() {
  command -v zsh >/dev/null 2>&1 || return 0

  local zsh_path
  zsh_path="$(command -v zsh)"
  grep -qx "$zsh_path" /etc/shells 2>/dev/null || echo "$zsh_path" | run_as_root tee -a /etc/shells >/dev/null
  if [[ "${SHELL:-}" != "$zsh_path" ]]; then
    step "login shell -> zsh"
    run_as_root chsh -s "$zsh_path" "$USER" || warn "chsh to zsh failed; set login shell manually"
  else
    ok "login shell already zsh"
  fi
}

export_sync_path() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh" --no-use
    nvm use --silent default >/dev/null 2>&1 || true
  fi

  export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
  mkdir -p "$PNPM_HOME/bin"

  export PATH="${NVM_BIN:+$NVM_BIN:}$PNPM_HOME/bin:$HOME/.local/bin:$HOME/.bun/bin:$HOME/.krew/bin:$HOME/.cargo/bin:$PATH"
}

install_apt_packages
