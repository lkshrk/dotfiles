#!/usr/bin/env bash
# Usage: ./setup.sh   Bootstraps a Mac or an Omarchy host; chezmoi does the rest. Safe to rerun.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
os=$(uname -s)
say() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
load_brew() { for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [[ -x $b ]] && eval "$("$b" shellenv)" && return; done; }

[[ -t 0 && -t 1 ]] || die "run from an interactive terminal; setup asks for passwords and Bitwarden"
case $os in
  Darwin)
    if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
      xcode-select --install || true
      die "install the Xcode Command Line Tools from the system prompt, then rerun ./setup.sh"
    fi
    load_brew || true
    have brew || { /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && load_brew; }
    have brew || die "Homebrew did not end up on PATH"
    brew install chezmoi mise
    sudo -v
    ;;
  Linux)
    [[ -d /usr/share/omarchy ]] || die "setup.sh supports macOS and Omarchy"
    have chezmoi || pkexec /usr/bin/pacman -S --needed --noconfirm chezmoi
    ;;
  *) die "unsupported OS: $os" ;;
esac
export PATH="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$HOME/.local/bin:$PATH"

# On a first run the repo's configs replace the fresh machine's defaults without asking.
force=()
[[ -f ${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml ]] || force=(--force)
say "chezmoi"
chezmoi init --source "$repo"
chezmoi apply ${force[@]+"${force[@]}"}
hash -r

if have rbw; then
  say "rbw"
  if [[ -z $(rbw config show 2>/dev/null | jq -r '.email // empty') ]]; then
    default_email=$(awk '{print $1; exit}' "$repo/home/dot_config/git/allowed_signers")
    read -rp "Bitwarden email [$default_email]: " email
    rbw config set email "${email:-$default_email}"
    read -rp "Bitwarden server URL (empty for bitwarden.com): " base_url
    [[ -z $base_url ]] || rbw config set base_url "$base_url"
  fi
  # i32::MAX seconds (~68 years): never, yet safe for rbw's Instant math.
  rbw config set lock_timeout 2147483647
  rbw unlocked >/dev/null 2>&1 || rbw unlock || warn "rbw stays locked; the LAN CA and the vault clone wait for the next run"
fi

if [[ $os == Linux ]]; then
  vault="$HOME/knowledge"
  if [[ ! -d $vault/.git ]] && rbw unlocked >/dev/null 2>&1; then
    say "knowledge vault"
    . "$repo/home/dot_config/env/lib/rbw-sock.sh"
    sock=$(env_next_rbw_sock_linux) && export SSH_AUTH_SOCK="$sock"
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git clone git@github.com:lkshrk/knowledge.git "$vault" ||
      warn "could not clone the knowledge vault; check the rbw SSH agent and rerun"
  fi
  [[ ! -d $vault/.git ]] || (cd "$vault" && lefthook install)
  if have obs && [[ ! -f $HOME/.config/obs-studio/basic/scenes/Untitled.json ]]; then
    say "obs"
    "$HOME/.local/bin/obs-config" apply || warn "OBS config not applied (vault locked or OBS running); run obs-config apply later"
  fi
fi

say "chezmoi, now that the vault is unlocked"
chezmoi apply

if [[ $os == Linux && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload >/dev/null
  errors=$(hyprctl configerrors)
  [[ -z ${errors//[[:space:]]/} ]] || die "Hyprland config errors: $errors"
fi
say "done; log out and back in to pick up the login shell and group changes"
