# 80-sync-reminder.zsh — nag when dotfiles haven't been synced in a while
# AND the repo/$HOME actually have drift.
#
# Opt-in:  touch ~/.cache/zsh/dotfiles-sync-reminder
# Disable: rm    ~/.cache/zsh/dotfiles-sync-reminder
#
# Stamps:
#   ~/.cache/zsh/dotfiles-last-sync    # mtime = last successful sync
#   ~/.cache/zsh/dotfiles-drift-check  # "yes"|"no", refreshed by drift-check.sh
#
# Strategy (fast path first):
#   1. If age < 30d → silent return (~80 µs, zsh builtins, zero forks).
#   2. If age ≥ 30d and drift cache is stale (>24h) → fire drift-check.sh
#      in the background (`&!`), detach, and exit. Next shell reads result.
#   3. If age ≥ 30d and cache says "yes" → print reminder.
#      If cache says "no" → stay quiet (repo is already clean).

() {
  local flag=$HOME/.cache/zsh/dotfiles-sync-reminder
  [[ -f $flag ]] || return

  local stamp=$HOME/.cache/zsh/dotfiles-last-sync
  local drift=$HOME/.cache/zsh/dotfiles-drift-check
  local -a st
  local last=0 drift_mtime=0 drift_value=""

  zmodload zsh/datetime 2>/dev/null
  zmodload zsh/stat     2>/dev/null

  if [[ -f $stamp ]] && zstat -A st +mtime -- $stamp 2>/dev/null; then
    last=$st[1]
  fi

  local now=${EPOCHSECONDS:-$(date +%s)}
  local age=$(( (now - last) / 86400 ))
  (( age < 30 )) && return

  if [[ -f $drift ]] && zstat -A st +mtime -- $drift 2>/dev/null; then
    drift_mtime=$st[1]
    drift_value="${$(<$drift)}"
  fi

  local cache_age=$(( now - drift_mtime ))
  if (( drift_mtime == 0 || cache_age > 86400 )); then
    local script="${DOTFILES_DIR:-$HOME/Dev/dotfiles}/scripts/drift-check.sh"
    [[ -x $script ]] && { $script &! } 2>/dev/null
    return
  fi

  [[ $drift_value == "yes" ]] || return

  print -P "%F{yellow}⚠  dotfiles last synced ${age}d ago, drift detected — run %F{cyan}dotsync%F{yellow} to update.%f"
}
