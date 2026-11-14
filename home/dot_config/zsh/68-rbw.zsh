# Exit 2 from rbw-unlock-once: no TTY or graphical session to prompt in.
rbw_unlock_if_needed() {
  (( $+commands[rbw] )) || return 1
  rbw unlocked >/dev/null 2>&1 || "${ENV_DIR:-$HOME/.config/env}/bin/rbw-unlock-once"
}

rbw_fix_ssh_auth_sock() {
  [[ -z ${SSH_AUTH_SOCK:-} || $SSH_AUTH_SOCK == /var/run/com.apple.launchd.*/Listeners ]] || return 0
  local sock os=linux
  [[ $OSTYPE == darwin* ]] && os=darwin
  sock=$(source "${ENV_DIR:-$HOME/.config/env}/lib/rbw-sock.sh" 2>/dev/null && env_rbw_sock_$os) || return 1
  export SSH_AUTH_SOCK=$sock
}

rbw_ssh_agent_ready() {
  rbw_fix_ssh_auth_sock && ssh-add -l >/dev/null 2>&1 && return 0
  rbw_unlock_if_needed || return
  rbw_fix_ssh_auth_sock && ssh-add -l >/dev/null 2>&1 && return 0
  print -u2 "rbw: SSH agent unreachable at ${SSH_AUTH_SOCK:-<unset>}"
  return 1
}

lazy_secret() {
  local var=$1 item=$2 val
  [[ -z ${(P)var} ]] || return 0
  if rbw_unlock_if_needed && val=$(rbw get "$item" 2>/dev/null) && [[ -n $val ]]; then
    typeset -gx "$var=$val"
    return 0
  fi
  print -u2 "rbw: could not retrieve '$item' for $var; vault may be locked, item may be missing, or rbw auth may need attention"
  return 1
}

hf_key()          { lazy_secret HF_TOKEN          hf-token; }
context7_key()    { lazy_secret CONTEXT7_API_KEY  context7-api-key; }
pocket_id_key()   { lazy_secret POCKET_ID_API_KEY pocket-id-api-key; }
h_cloud_age_key() { lazy_secret SOPS_AGE_KEY      h-cloud-age-key; }

rbw_env() { "${ENV_DIR:-$HOME/.config/env}/bin/rbw-env" "$@"; }

(( $+commands[rbw] )) || return 0

sops() { rbw_env sops -- sops "$@"; }

# Signing (commit/tag/merge) and SSH remotes need rbw's SSH agent.
git() {
  # Agent shell snapshots can carry this wrapper without its helpers.
  (( $+functions[rbw_unlock_if_needed] )) || { command git "$@"; return; }
  case ${1:-} in
    commit|tag|merge)
      (( ${+compstate} )) || rbw_unlock_if_needed || (( $? == 2 )) || return ;;
    push|pull|fetch|clone|ls-remote|submodule)
      if (( ${+compstate} )); then rbw_fix_ssh_auth_sock; else rbw_ssh_agent_ready; fi ;;
  esac
  command git "$@"
}
