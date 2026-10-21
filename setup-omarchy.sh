#!/usr/bin/env bash
# setup-omarchy.sh - Omarchy (Arch Linux) workstation bootstrap for this dotfiles repo.
#
# Fresh machine, one line (stdin stays the terminal for sudo and rbw prompts):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/lkshrk/dotfiles/main/setup-omarchy.sh)"
#
# Safe to rerun. DOTFILES_DIR (default ~/Dev/dotfiles) and DOTFILES_REF pick the
# checkout and branch used when the script is not run from a checkout.

set -euo pipefail

REPO_URL="https://github.com/lkshrk/dotfiles.git"
OMNI_REPO="lkshrk/omni"

c_red=$'\033[31m'
c_yel=$'\033[33m'
c_grn=$'\033[32m'
c_dim=$'\033[2m'
c_off=$'\033[0m'

say()  { printf '%s\n' "$*"; }
step() { say "${c_dim}-- $* --${c_off}"; }
ok()   { say "${c_grn}ok${c_off} $*"; }
warn() { say "${c_yel}!${c_off} $*" >&2; }
die()  { say "${c_red}x${c_off} $*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" && -d /usr/share/omarchy ]] || die "setup-omarchy.sh is for Omarchy hosts"
[[ -t 0 && -t 1 ]] || die "run from an interactive terminal; setup prompts for sudo and Bitwarden"

# ─── Checkout ─────────────────────────────────────────────────────────────────
# Run through curl, there is no checkout yet: clone one and continue from it.

self="${BASH_SOURCE[0]:-}"
if [[ -z "$self" || ! -f "$(dirname "$self")/dotfiles/omni/.config/omni/settings.json" ]]; then
  dir="${DOTFILES_DIR:-$HOME/Dev/dotfiles}"
  if [[ ! -d "$dir/.git" ]]; then
    step "clone $REPO_URL"
    git clone ${DOTFILES_REF:+--branch "$DOTFILES_REF"} "$REPO_URL" "$dir"
  fi
  exec bash "$dir/setup-omarchy.sh" "$@"
fi

REPO_DIR="$(cd "$(dirname "$self")" && pwd)"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
FIRST_RUN_MARKER="$STATE_DIR/omarchy-setup-done"
omni() { command omni --config "$OMNI_CONFIG_PATH" "$@"; }

# Run omni under the same env spine as the login shell (BUN_INSTALL, PNPM_HOME,
# NVM_DIR, PATH), so tools land where the shell later looks for them. Loaded
# from the checkout: on a fresh machine ~/.config/env is not linked yet.
set +u
ENV_DIR="$REPO_DIR/dotfiles/env/.config/env" . "$REPO_DIR/dotfiles/env/.config/env/profile.sh"
set -u

step "admin session"
sudo -v
ok "sudo credentials cached for this terminal"

# ─── Omni ─────────────────────────────────────────────────────────────────────
# Reading the config is the real requirement (the aur provider needs settings
# v26), so an older omni is replaced by the latest release's Arch package.

omni_reads_config() { command -v omni >/dev/null 2>&1 && omni settings show --format json >/dev/null 2>&1; }

install_omni_release() (
  set -euo pipefail
  release=$(curl -fsSLI --proto-redir '=https' -o /dev/null -w '%{url_effective}' "https://github.com/$OMNI_REPO/releases/latest")
  tag=${release##*/}
  asset="omni-${tag#v}-1-$(uname -m).pkg.tar.zst"
  base="https://github.com/$OMNI_REPO/releases/download/$tag"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL --proto-redir '=https' "$base/$asset" -o "$tmp/$asset"
  curl -fsSL --proto-redir '=https' "$base/checksums.txt" -o "$tmp/checksums.txt"
  (cd "$tmp" && grep -F "  $asset" checksums.txt | sha256sum -c -)
  sudo pacman -U --needed --noconfirm "$tmp/$asset"
)

step "omni"
if ! omni_reads_config; then
  install_omni_release
  hash -r
  omni_reads_config || die "omni $(command omni --version 2>/dev/null) cannot read this repo's config; it needs a release with settings v26"
fi
ok "$(command omni --version)"

# ─── First run: the repo's configs win ────────────────────────────────────────
# A fresh install's configs are distro or app defaults. Later runs keep local
# edits instead (volatile-dots preserves them; conflicts are left to resolve).

if [[ ! -e "$FIRST_RUN_MARKER" ]]; then
  step "first run: take the repo's configs"
  stamp=$(date +%Y%m%d%H%M%S)
  while IFS= read -r entry; do
    [[ -n "$entry" && "$entry" != \#* ]] || continue
    rel="${entry#dotfiles/}"
    target="$HOME/${rel#*/}"
    if [[ -f "$target" && ! -L "$target" ]]; then
      mv "$target" "$target.pre-dotfiles.$stamp"
      ok "kept the default as ${target/#"$HOME"/\~}.pre-dotfiles.$stamp"
    fi
  done < "$REPO_DIR/scripts/volatile-dots.txt"
  # Resolving links with stow; omni installs it first when it is missing.
  mapfile -t conflicts < <(omni dots status --state conflict --format json | jq -r '.entries[]?.name')
  for name in "${conflicts[@]}"; do
    omni --yes dots resolve "$name" --use-repo
  done
fi

# ─── Tools and dots ───────────────────────────────────────────────────────────
# Omni installs its own prerequisites: stow before linking dots, and the package
# managers this host lists as tools (bun, uv, ...) before their dependents.

# A tool that fails to install must not stop the rest of the setup: exit 3 marks
# that, and the run reports it at the end. set -e does not apply inside a
# subshell tested with ||, so each step exits explicitly.
tools_failed=0
rc=0
(
  # Preserve runtime edits and never leave agent-writable files linked to git.
  bash "$REPO_DIR/scripts/volatile-dots.sh" detach || exit 2
  trap 'bash "$REPO_DIR/scripts/volatile-dots.sh" detach' EXIT
  bash "$REPO_DIR/scripts/volatile-dots.sh" prepare || exit 2
  step "omni bootstrap"
  omni --yes bootstrap --no-import || exit 2
  bash "$REPO_DIR/scripts/volatile-dots.sh" detach || exit 2

  step "omni tools"
  omni --yes tools sync || exit 3
) || rc=$?
case "$rc" in
  0) ;;
  3) tools_failed=1; warn "some tools failed to install; continuing with the rest of the setup" ;;
  *) die "omni bootstrap failed" ;;
esac

# ─── Omarchy defaults this setup does not want ────────────────────────────────

step "omarchy defaults"
mapfile -t drop < <(grep -v -e '^#' -e '^[[:space:]]*$' "$REPO_DIR/omarchy/remove.packages")
((${#drop[@]} == 0)) || omarchy pkg drop "${drop[@]}"
while IFS= read -r webapp; do
  [[ -n "$webapp" && "$webapp" != \#* ]] || continue
  [[ -e "$HOME/.local/share/applications/$webapp.desktop" ]] || continue
  omarchy webapp remove "$webapp"
  ok "removed web app $webapp"
done < "$REPO_DIR/omarchy/remove.webapps"

# ─── Login shell ──────────────────────────────────────────────────────────────

step "login shell"
zsh_path="$(command -v zsh || true)"
if [[ -z "$zsh_path" ]]; then
  warn "zsh is not installed; Omni should install it through the shell group"
elif [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
  chsh -s "$zsh_path"
  ok "login shell is now $zsh_path (takes effect on next login)"
else
  ok "login shell is $zsh_path"
fi

# ─── Caps Lock → Hyper ────────────────────────────────────────────────────────
# keyd itself comes from the omarchy group.

step "keyd"
sudo install -Dm644 "$REPO_DIR/omarchy/keyd/default.conf" /etc/keyd/default.conf
# Restart rather than `keyd reload`: right after the first start the socket
# isn't up yet, and a restart also picks up config changes on later runs.
sudo systemctl enable keyd
sudo systemctl restart keyd
ok "Caps Lock is Hyper"

# ─── Docker ───────────────────────────────────────────────────────────────────
# docker itself comes from the dev-tooling group; the group is root-equivalent.

step "docker"
if command -v docker >/dev/null 2>&1; then
  sudo systemctl enable --now docker.socket
  if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    ok "$USER is in the docker group"
  else
    sudo usermod -aG docker "$USER"
    ok "$USER joined the docker group (takes effect on next login)"
  fi
else
  warn "docker is not installed; Omni should install it through the dev-tooling group"
fi

# ─── Helium as the default browser ────────────────────────────────────────────
# `omarchy default browser` has no Helium option, so set the XDG handler the same
# way it does.

helium_desktop="$(pacman -Qlq helium-browser-bin 2>/dev/null | grep -m1 '/usr/share/applications/.*\.desktop$' || true)"
if [[ -n "$helium_desktop" ]]; then
  env -u BROWSER XDG_CURRENT_DESKTOP= xdg-settings set default-web-browser "$(basename "$helium_desktop")"
  ok "Helium is the default browser"
fi

# ─── Bitwarden (rbw): secrets, SSH agent and commit signing ───────────────────
# rbw's account settings are not a dot, so the first run asks for them.

step "rbw"
if ! command -v rbw >/dev/null 2>&1; then
  warn "rbw is not installed; Omni should install it through the secrets group"
else
  if [[ -z "$(rbw config show 2>/dev/null | jq -r '.email // empty')" ]]; then
    default_email="$(awk '{print $1; exit}' "$REPO_DIR/dotfiles/git/.config/git/allowed_signers")"
    read -rp "Bitwarden email [$default_email]: " email
    rbw config set email "${email:-$default_email}"
    read -rp "Bitwarden server URL (empty for bitwarden.com): " base_url
    [[ -z "$base_url" ]] || rbw config set base_url "$base_url"
  fi
  # i32::MAX seconds (~68 years): never, yet safe for Instant math on every platform.
  rbw_lock_timeout=2147483647
  if [[ "$(rbw config show 2>/dev/null | jq -r '.lock_timeout // empty')" != "$rbw_lock_timeout" ]]; then
    rbw config set lock_timeout "$rbw_lock_timeout"
  fi
  rbw unlocked >/dev/null 2>&1 || rbw unlock
  ok "vault unlocked"
fi

# ─── LAN root CA ──────────────────────────────────────────────────────────────
# The vault keeps the PEM on one line in the username field; rewrap it before trusting.

step "lan ca"
lan_ca="$HOME/.local/share/certs/lan-ca.pem"
lan_ca_anchor=/etc/ca-certificates/trust-source/anchors/lan-ca.crt
if rbw unlocked >/dev/null 2>&1 && raw="$(rbw get --field username root-CA 2>/dev/null)" && [[ -n "$raw" ]]; then
  body="$(sed -e 's/-----BEGIN CERTIFICATE-----//' -e 's/-----END CERTIFICATE-----//' <<<"$raw" | tr -d '[:space:]')"
  mkdir -p "${lan_ca%/*}"
  tmp="$(mktemp "$lan_ca.tmp.XXXXXX")"
  { echo "-----BEGIN CERTIFICATE-----"; fold -w64 <<<"$body"; echo "-----END CERTIFICATE-----"; } >"$tmp"
  if openssl x509 -in "$tmp" -noout 2>/dev/null; then
    mv "$tmp" "$lan_ca"
    if ! cmp -s "$lan_ca" "$lan_ca_anchor"; then
      sudo install -Dm644 "$lan_ca" "$lan_ca_anchor"
      sudo update-ca-trust
    fi
    ok "LAN root CA is trusted system-wide"
  else
    rm -f "$tmp"
    warn "vault item root-CA is not a valid certificate; LAN hosts (litellm) will fail TLS"
  fi
else
  warn "could not read root-CA from the vault; LAN hosts (litellm) will fail TLS"
fi

# ─── Agents ───────────────────────────────────────────────────────────────────
# After the CA: APM fetches the litellm marketplace from a LAN host.

step "omni agents"
if omni --yes agents sync; then
  ok "agent plugins and hooks installed"
else
  warn "omni agents sync failed; rerun it once the cause is fixed"
fi

# ─── Knowledge vault ──────────────────────────────────────────────────────────
# The rbw SSH agent socket only exists after the unlock above, so adopt it now.

step "knowledge vault"
vault="$HOME/knowledge"
. "$REPO_DIR/dotfiles/env/.config/env/lib/rbw-sock.sh"
rbw_sock="$(env_next_rbw_sock_linux)" && export SSH_AUTH_SOCK="$rbw_sock"
if [[ ! -d "$vault/.git" ]]; then
  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git clone git@github.com:lkshrk/knowledge.git "$vault" \
    || warn "could not clone the knowledge vault; check the rbw SSH agent and rerun"
fi
if [[ -d "$vault/.git" ]]; then
  if systemctl --user daemon-reload && systemctl --user enable --now knowledge-sync.timer; then
    ok "knowledge vault syncs every 5 minutes"
  else
    warn "could not enable knowledge-sync.timer (no user systemd bus?); rerun setup from a desktop session"
  fi
fi

# ─── Lefthook ─────────────────────────────────────────────────────────────────

step "lefthook"
if command -v lefthook >/dev/null 2>&1; then
  (cd "$REPO_DIR" && lefthook install)
  [[ ! -d "$HOME/knowledge/.git" ]] || (cd "$HOME/knowledge" && lefthook install)
  ok "lefthook installed"
else
  warn "lefthook is not installed; Omni should install it through the dev group"
fi

# ─── Hyprland ─────────────────────────────────────────────────────────────────

step "hyprland"
hyprctl reload >/dev/null
errors="$(hyprctl configerrors)"
[[ -z "${errors//[[:space:]]/}" ]] || die "$errors"
ok "config loads cleanly"

mkdir -p "$STATE_DIR"
touch "$FIRST_RUN_MARKER"
if ((tools_failed)); then
  warn "setup finished, but some tools failed to install (listed above under omni tools)"
  warn "fix the cause, then run: omni --config $OMNI_CONFIG_PATH tools sync --retry-failed"
  exit 1
fi
say "${c_grn}Omarchy setup done.${c_off} Log out and back in to start zsh."
