#!/usr/bin/env bash

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

# The login shell's env spine, from the checkout: ~/.config/env is not linked yet on a fresh machine.
set +u
ENV_DIR="$REPO_DIR/dotfiles/env/.config/env" . "$REPO_DIR/dotfiles/env/.config/env/profile.sh"
set -u

step "admin session"
sudo -v
ok "sudo credentials cached for this terminal"

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

if ((first_run)); then
  status_json="$(omni dots status --state conflict --format json)" || die "omni dots status failed"
  mapfile -t conflicts < <(jq -r '.entries[]?.name' <<<"$status_json")
  for name in "${conflicts[@]}"; do
    omni --yes dots resolve "$name" --use-repo
  done
  mkdir -p "$STATE_DIR"
  touch "$FIRST_RUN_MARKER"
fi

step "omarchy defaults"
mapfile -t drop < <(grep -v -e '^#' -e '^[[:space:]]*$' "$REPO_DIR/omarchy/remove.packages")
((${#drop[@]} == 0)) || omarchy pkg drop "${drop[@]}"
while IFS= read -r webapp; do
  [[ -n "$webapp" && "$webapp" != \#* ]] || continue
  OMARCHY_REMOVE_NOTIFY=false omarchy-webapp-remove "$webapp"
done < "$REPO_DIR/omarchy/remove.webapps"
ok "unwanted Omarchy web apps removed"

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

if have keyd; then
  step "keyd"
  # Restart rather than `keyd reload`: right after the first start the socket isn't up yet.
  keyd_changed=0
  for conf in common default.conf mac.conf scimitar.conf; do
    if ! cmp -s "$REPO_DIR/omarchy/keyd/$conf" "/etc/keyd/$conf"; then
      sudo install -Dm644 "$REPO_DIR/omarchy/keyd/$conf" "/etc/keyd/$conf"
      keyd_changed=1
    fi
  done
  if ((keyd_changed)) || ! systemctl is-active --quiet keyd; then
    sudo keyd check /etc/keyd/*.conf >/dev/null || die "keyd rejected the config in /etc/keyd"
    sudo systemctl enable keyd
    sudo systemctl restart keyd
  fi
  # keyd-application-mapper (terminal Cmd mappings) talks to keyd's socket, which only the keyd group may use.
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx keyd; then
    sudo usermod -aG keyd "$USER"
    warn "added $USER to the keyd group; log out and back in for terminal Cmd + C/V"
  fi
  ok "Mac keymap: Cmd sends Ctrl, Ctrl sends Super, Caps is Hyper"
fi

step "mounts"
fstab_begin="# BEGIN dotfiles mounts"
fstab_end="# END dotfiles mounts"
fstab_new="$(mktemp)"
{
  # Drops the old block and any unmanaged line for the same targets, so reruns and older hand edits converge.
  awk -v b="$fstab_begin" -v e="$fstab_end" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    skip { next }
    $2 == "/mnt/stuff" || $2 == "/mnt/games" || $2 == "/mnt/gaming" { next }
    # The ESP holds the random seed, so it must not be world-readable (bootctl warns at every boot).
    $2 == "/boot" && $3 == "vfat" { sub(/fmask=0022/, "fmask=0077"); sub(/dmask=0022/, "dmask=0077") }
    { print }
  ' /etc/fstab
  printf '%s\n' "$fstab_begin"
  cat "$REPO_DIR/omarchy/fstab.mounts"
  printf '%s\n' "$fstab_end"
} >"$fstab_new"
units_changed=0
for unit in ntfsfix-stuff.service mnt-stuff.mount.d/ntfsfix.conf; do
  if ! cmp -s "$REPO_DIR/omarchy/systemd/$unit" "/etc/systemd/system/$unit"; then
    sudo install -Dm644 "$REPO_DIR/omarchy/systemd/$unit" "/etc/systemd/system/$unit"
    units_changed=1
  fi
done
if ! cmp -s "$fstab_new" /etc/fstab; then
  sudo cp /etc/fstab "/etc/fstab.bak-dotfiles.$(date +%Y%m%d%H%M%S)"
  sudo install -m644 "$fstab_new" /etc/fstab
  sudo mkdir -p /mnt/stuff /mnt/gaming
  units_changed=1
fi
rm -f "$fstab_new"
if ((units_changed)); then
  sudo systemctl daemon-reload
  sudo systemctl start mnt-stuff.mount mnt-gaming.automount || warn "a mount did not come up; it retries at next boot"
fi
ok "STUFF on /mnt/stuff (ntfsfix before mount), NAS gaming share automounts on /mnt/gaming"

# Proton prefixes break on NTFS, so the STUFF library keeps them on the home disk.
stuff_library=/mnt/stuff/Games/SteamLibrary/steamapps
home_compat="$HOME/.local/share/Steam/steamapps/compatdata"
if [[ -d $stuff_library && ! -L $stuff_library/compatdata ]]; then
  if [[ -e $stuff_library/compatdata ]]; then
    warn "$stuff_library/compatdata is a real folder; move its prefixes to $home_compat and rerun"
  else
    mkdir -p "$home_compat"
    ln -s "$home_compat" "$stuff_library/compatdata"
  fi
fi
[[ -L $stuff_library/compatdata ]] && ok "STUFF Steam library keeps Proton prefixes in $home_compat"

step "system tweaks"
if have cloudflared; then
  dropin=cloudflared.service.d/wait-dns.conf
  if ! cmp -s "$REPO_DIR/omarchy/systemd/$dropin" "/etc/systemd/system/$dropin"; then
    sudo install -Dm644 "$REPO_DIR/omarchy/systemd/$dropin" "/etc/systemd/system/$dropin"
    sudo systemctl daemon-reload
  fi
fi
if have irqbalance && ! cmp -s "$REPO_DIR/omarchy/default/irqbalance" /etc/default/irqbalance; then
  sudo install -Dm644 "$REPO_DIR/omarchy/default/irqbalance" /etc/default/irqbalance
  sudo systemctl try-restart irqbalance
fi
# ufw owns before.rules, so only this one rule is added rather than shipping the whole file.
ufw_rule='-A ufw-before-input -p igmp -d 224.0.0.1 -j DROP'
if have ufw && ! sudo grep -qxF -- "$ufw_rule" /etc/ufw/before.rules; then
  sudo sed -i "/-d 224.0.0.251 --dport 5353 -j ACCEPT/a\\
\\
# drop the router's IGMP membership queries without logging them\\
$ufw_rule" /etc/ufw/before.rules
  sudo ufw reload >/dev/null
fi
ok "cloudflared waits for DNS, irqbalance skips NVMe queues, ufw stops logging IGMP queries"

step "opendeck images"
# OpenDeck refuses to draw slot images that are symlinks out of its own folder, so these are copied, never linked.
# --update=none keeps icons changed in the GUI since; new ones from the repo still arrive.
mkdir -p "$HOME/.config/opendeck/images"
cp -r --update=none "$REPO_DIR/templates/opendeck-images/." "$HOME/.config/opendeck/images/"
ok "Stream Deck icons in place"

if have obs; then
  step "obs"
  # Only seeds a machine without OBS scenes yet; later changes go back to the repo with `obs-config export`.
  if [[ -f "$HOME/.config/obs-studio/basic/scenes/Untitled.json" ]]; then
    ok "OBS already configured; run obs-config apply to replace it with the repo version"
  elif "$HOME/.local/bin/obs-config" apply; then
    ok "OBS scenes, profile and websocket restored, secrets from the vault"
  else
    warn "OBS config not applied (vault locked or OBS running); run obs-config apply later"
  fi
fi

if have docker; then
  step "docker"
  sudo systemctl enable --now docker.socket
  OMARCHY_DEFER_REBOOT=1 omarchy-setup-security-sudoless-docker
fi

# `omarchy default browser` has no Helium option.
helium_desktop="$(pacman -Qlq helium-browser-bin 2>/dev/null | grep -m1 '/usr/share/applications/.*\.desktop$' || true)"
if [[ -n "$helium_desktop" ]]; then
  env -u BROWSER XDG_CURRENT_DESKTOP= xdg-settings set default-web-browser "$(basename "$helium_desktop")"
  ok "Helium is the default browser"
fi

roller_desktop=/usr/share/applications/org.gnome.FileRoller.desktop
if [[ -f "$roller_desktop" ]]; then
  mapfile -t roller_types < <(sed -n 's/^MimeType=//p' "$roller_desktop" | tr ';' '\n' | grep .)
  xdg-mime default org.gnome.FileRoller.desktop "${roller_types[@]}"
  ok "File Roller opens ${#roller_types[@]} archive types"
fi

# omarchy-launch-webapp always uses the default browser, so these get their own Exec.
# gtk-launch expands neither ~ nor $HOME, so the focus-or-launch wrapper needs its absolute path.
step "web apps"
while IFS='|' read -r name url icon; do
  [[ -n "$name" && "$name" != \#* ]] || continue
  rest="${url#*://}"
  host="${rest%%/*}"
  host="${host%%:*}"
  url_path="/"
  [[ "$rest" != */* ]] || url_path="/${rest#*/}"
  exec_cmd="$HOME/.local/bin/webapp-focus $url"
  exec_line="Exec=$exec_cmd"
  wm_class_line="StartupWMClass=chrome-${host}_${url_path//\//_}-Default"
  desktop="$HOME/.local/share/applications/$name.desktop"
  if ! { grep -qxF "$exec_line" "$desktop" && grep -qxF "$wm_class_line" "$desktop"; } 2>/dev/null; then
    if ! omarchy-webapp-install "$name" "$url" "$icon" "$exec_cmd" >/dev/null; then
      warn "web app $name could not be installed"
      continue
    fi
    printf '%s\n' "$wm_class_line" >>"$desktop"
  fi
  ok "web app $name opens in Chromium"
done < "$REPO_DIR/omarchy/chromium.webapps"

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

# After the CA: APM fetches the litellm marketplace from a LAN host.
step "omni agents"
if omni --yes agents sync; then
  ok "agent plugins and hooks installed"
else
  warn "omni agents sync failed; rerun it once the cause is fixed"
fi

# The rbw SSH agent socket exists only after the unlock above.
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

if have lefthook; then
  step "lefthook"
  install_lefthook "$REPO_DIR" "$HOME/knowledge"
fi

step "hyprland"
# screens/top.lua stores each app's top-screen side here and cannot create it from inside the compositor.
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/hypr-screens"
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
