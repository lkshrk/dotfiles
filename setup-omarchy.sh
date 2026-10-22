#!/usr/bin/env bash
# setup-omarchy.sh - Omarchy (Arch Linux) workstation bootstrap for this dotfiles repo.
#
#
# Safe to rerun.

set -euo pipefail

OMNI_REPO="lkshrk/omni"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMNI_CONFIG_PATH="${OMNI_CONFIG:-$REPO_DIR/dotfiles/omni/.config/omni/settings.json}"

. "$REPO_DIR/scripts/lib/setup-common.sh"

[[ "$(uname -s)" == "Linux" && -d /usr/share/omarchy ]] || die "setup-omarchy.sh is for Omarchy hosts"
[[ -t 0 && -t 1 ]] || die "run from an interactive terminal; setup prompts for sudo and Bitwarden"

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
# Reading the config is the real requirement (settings v26), so an older omni is
# replaced in ~/.local/bin, where the omni tool's script provider keeps it.

omni_reads_config() { command -v omni >/dev/null 2>&1 && omni settings show --format json >/dev/null 2>&1; }

install_omni_release() (
  set -euo pipefail
  release=$(curl -fsSLI --proto-redir '=https' -o /dev/null -w '%{url_effective}' "https://github.com/$OMNI_REPO/releases/latest")
  tag=${release##*/}
  asset="omni_linux_$(uname -m).tar.gz"
  base="https://github.com/$OMNI_REPO/releases/download/$tag"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL --proto-redir '=https' "$base/$asset" -o "$tmp/$asset"
  curl -fsSL --proto-redir '=https' "$base/checksums.txt" -o "$tmp/checksums.txt"
  (cd "$tmp" && grep -F "  $asset" checksums.txt | sha256sum -c -)
  tar -xzf "$tmp/$asset" -C "$tmp" omni
  install -Dm755 "$tmp/omni" "$HOME/.local/bin/omni"
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

first_run=0
[[ -e "$FIRST_RUN_MARKER" ]] || first_run=1
if ((first_run)); then
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
  omni_bootstrap_dots || exit 2

  step "omni tools"
  omni --yes tools sync || exit 3
) || rc=$?
case "$rc" in
  0) ;;
  3) tools_failed=1; warn "some tools failed to install; continuing with the rest of the setup" ;;
  *) die "omni bootstrap failed" ;;
esac

hash -r
missing=()
for cmd in zsh keyd docker rbw lefthook; do
  have "$cmd" || missing+=("$cmd")
done
((${#missing[@]} == 0)) || warn "not installed, so their steps are skipped: ${missing[*]} (rerun once omni tools sync installs them)"

# After bootstrap, so the host is active and stow is installed.
if ((first_run)); then
  status_json="$(omni dots status --state conflict --format json)" || die "omni dots status failed"
  mapfile -t conflicts < <(jq -r '.entries[]?.name' <<<"$status_json")
  for name in "${conflicts[@]}"; do
    omni --yes dots resolve "$name" --use-repo
  done
  mkdir -p "$STATE_DIR"
  touch "$FIRST_RUN_MARKER"
fi

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

if have zsh; then
  step "login shell"
  zsh_path="$(command -v zsh)"
  if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
    chsh -s "$zsh_path"
    ok "login shell is now $zsh_path (takes effect on next login)"
  else
    ok "login shell is $zsh_path"
  fi
fi

# ─── Caps Lock → Hyper ────────────────────────────────────────────────────────
# keyd itself comes from the omarchy group.

if have keyd; then
  step "keyd"
  # Restart rather than `keyd reload`: right after the first start the socket isn't up yet.
  if ! cmp -s "$REPO_DIR/omarchy/keyd/default.conf" /etc/keyd/default.conf || ! systemctl is-active --quiet keyd; then
    sudo install -Dm644 "$REPO_DIR/omarchy/keyd/default.conf" /etc/keyd/default.conf
    sudo systemctl enable keyd
    sudo systemctl restart keyd
  fi
  ok "Caps Lock is Hyper"
fi

# ─── Docker ───────────────────────────────────────────────────────────────────
# docker itself comes from the dev-tooling group; the group is root-equivalent.

if have docker; then
  step "docker"
  sudo systemctl enable --now docker.socket
  OMARCHY_DEFER_REBOOT=1 omarchy-setup-security-sudoless-docker
fi

# ─── Helium as the default browser ────────────────────────────────────────────
# `omarchy default browser` has no Helium option, so set the XDG handler the same
# way it does.

helium_desktop="$(pacman -Qlq helium-browser-bin 2>/dev/null | grep -m1 '/usr/share/applications/.*\.desktop$' || true)"
if [[ -n "$helium_desktop" ]]; then
  env -u BROWSER XDG_CURRENT_DESKTOP= xdg-settings set default-web-browser "$(basename "$helium_desktop")"
  ok "Helium is the default browser"
fi

# ─── Web apps in Chromium ─────────────────────────────────────────────────────
# omarchy-launch-webapp always uses the default browser, so these get their own Exec.

step "web apps"
while IFS='|' read -r name url icon; do
  [[ -n "$name" && "$name" != \#* ]] || continue
  if ! omarchy-webapp-install "$name" "$url" "$icon" "chromium --app=$url" >/dev/null; then
    warn "web app $name could not be installed"
    continue
  fi
  rest="${url#*://}"
  host="${rest%%/*}"
  host="${host%%:*}"
  url_path="/"
  [[ "$rest" != */* ]] || url_path="/${rest#*/}"
  printf 'StartupWMClass=chrome-%s_%s-Default\n' "$host" "${url_path//\//_}" \
    >> "$HOME/.local/share/applications/$name.desktop"
  ok "web app $name opens in Chromium"
done < "$REPO_DIR/omarchy/chromium.webapps"

# ─── Bitwarden (rbw): secrets, SSH agent and commit signing ───────────────────
# rbw's account settings are not a dot, so the first run asks for them.

if have rbw; then
  step "rbw"
  if [[ -z "$(rbw config show 2>/dev/null | jq -r '.email // empty')" ]]; then
    default_email="$(awk '{print $1; exit}' "$REPO_DIR/dotfiles/git/.config/git/allowed_signers")"
    read -rp "Bitwarden email [$default_email]: " email
    rbw config set email "${email:-$default_email}"
    read -rp "Bitwarden server URL (empty for bitwarden.com): " base_url
    [[ -z "$base_url" ]] || rbw config set base_url "$base_url"
  fi
  rbw_set_lock_timeout
  rbw unlocked >/dev/null 2>&1 || rbw unlock
  ok "vault unlocked"

  step "lan ca"
  bash "$REPO_DIR/scripts/lan-ca.sh" || warn "continuing without the LAN root CA"
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

if have lefthook; then
  step "lefthook"
  install_lefthook "$REPO_DIR" "$HOME/knowledge"
fi

# ─── Hyprland ─────────────────────────────────────────────────────────────────

step "hyprland"
hyprctl reload >/dev/null
errors="$(hyprctl configerrors)"
[[ -z "${errors//[[:space:]]/}" ]] || die "$errors"
ok "config loads cleanly"

if ((tools_failed)); then
  warn "setup finished, but some tools failed to install (listed above under omni tools)"
  warn "fix the cause, then run: omni --config $OMNI_CONFIG_PATH tools sync --retry-failed"
  exit 1
fi
say "${c_grn}Omarchy setup done.${c_off} Log out and back in to start zsh."
