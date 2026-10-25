# Lazy secret helpers via rbw; command wrappers go through ~/.config/env/bin/rbw-env.

rbw_available() {
  (( $+commands[rbw] )) || return 1
  rbw config show >/dev/null 2>&1
}

rbw_can_prompt() {
  [[ -o interactive && -t 0 && -t 1 && -r /dev/tty ]]
}

rbw_unlock_if_needed() {
  rbw_available || return 1
  rbw unlocked >/dev/null 2>&1 && return 0

  if rbw_can_prompt; then
    print -u2 "rbw: vault locked; unlocking"
    rbw unlock </dev/tty >/dev/tty 2>/dev/tty && rbw unlocked >/dev/null 2>&1
    return
  fi

  return 1
}

rbw_fix_ssh_auth_sock() {
  [[ -z ${SSH_AUTH_SOCK:-} || $SSH_AUTH_SOCK == /var/run/com.apple.launchd.*/Listeners ]] || return 0
  local sock os=linux
  [[ $OSTYPE == darwin* ]] && os=darwin
  sock=$(source "$ENV_DIR/lib/rbw-sock.sh" 2>/dev/null && env_next_rbw_sock_$os) || return 1
  export SSH_AUTH_SOCK=$sock
}

rbw_ssh_agent_ready() {
  local attempt
  for attempt in 1 2; do
    rbw_fix_ssh_auth_sock && [[ -S ${SSH_AUTH_SOCK:-} ]] && ssh-add -l >/dev/null 2>&1 && return 0
    (( attempt == 1 )) || break
    { rbw_available && rbw_can_prompt; } || { print -u2 "rbw: SSH agent unavailable; run 'rbw unlock' in an interactive shell"; return 1; }
    rbw_unlock_if_needed || break
  done
  print -u2 "rbw: SSH agent unreachable at ${SSH_AUTH_SOCK:-<unset>}"; return 1
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

hf_key()       { lazy_secret HF_TOKEN          hf-token; }
context7_key() { lazy_secret CONTEXT7_API_KEY  context7-api-key; }
pocket_id_key()   { lazy_secret POCKET_ID_API_KEY    pocket-id-api-key; }
h_cloud_age_key() { lazy_secret SOPS_AGE_KEY    h-cloud-age-key; }

rbw_env() {
  local wrapper="$ENV_DIR/bin/rbw-env"
  if [[ -x "$wrapper" ]]; then
    "$wrapper" "$@"
  else
    print -u2 "rbw-env: wrapper unavailable"
    return 127
  fi
}

(( $+commands[rbw] )) || return 0

sops() {
  rbw_env sops -- sops "$@"
}

git() {
  # Snapshotted shells (agents) can carry this wrapper without its helpers.
  (( $+functions[rbw_can_prompt] )) || { command git "$@"; return; }
  case "${1:-}" in
    commit|tag|merge|push|pull|fetch|clone|ls-remote|submodule)
      if (( ! ${+compstate} )) && rbw_can_prompt; then
        case $1 in
          commit|tag|merge) rbw_unlock_if_needed || return ;;
          *) rbw_ssh_agent_ready ;;
        esac
      else
        rbw_fix_ssh_auth_sock >/dev/null 2>&1
      fi
      ;;
  esac
  command git "$@"
}
