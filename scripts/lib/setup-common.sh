# shellcheck shell=bash

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
have() { command -v "$1" >/dev/null 2>&1; }

# Call in a subshell: the EXIT trap detaches volatile dots again when that subshell ends.
omni_bootstrap_dots() {
  local volatile="$REPO_DIR/scripts/volatile-dots.sh"
  bash "$volatile" detach || return
  trap 'bash "$REPO_DIR/scripts/volatile-dots.sh" detach' EXIT
  bash "$volatile" prepare || return
  step "omni bootstrap"
  command omni --config "$OMNI_CONFIG_PATH" --yes bootstrap --no-import || return
  bash "$volatile" detach
}

# Returns non-zero only when the vault stays locked; a missing LAN CA just warns.
rbw_unlock_with_lan_ca() {
  # i32::MAX seconds (~68 years): never, yet safe for Instant math on every platform.
  local lock_timeout=2147483647
  if [[ "$(rbw config show 2>/dev/null | jq -r '.lock_timeout // empty')" != "$lock_timeout" ]]; then
    rbw config set lock_timeout "$lock_timeout" || die "could not set the rbw lock timeout"
  fi
  ok "rbw never locks on a timeout"
  rbw unlocked >/dev/null 2>&1 || rbw unlock || return
  ok "vault unlocked"

  step "lan ca"
  bash "$REPO_DIR/scripts/lan-ca.sh" || warn "continuing without the LAN root CA"
}

install_lefthook() {
  local dir
  for dir in "$@"; do
    [[ -e "$dir/.git" ]] || continue
    (cd "$dir" && lefthook install)
  done
  ok "lefthook installed"
}
