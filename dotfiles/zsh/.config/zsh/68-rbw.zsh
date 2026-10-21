# Lazy secret helpers via rbw; command wrappers go through ~/.config/env/bin/rbw-env.

_rbw_available() {
  (( $+commands[rbw] )) || return 1
  rbw config show >/dev/null 2>&1
}

_rbw_can_prompt() {
  [[ -o interactive && -t 0 && -t 1 && -r /dev/tty ]]
}

_rbw_unlock_if_needed() {
  _rbw_available || return 1
  rbw unlocked >/dev/null 2>&1 && return 0

  if _rbw_can_prompt; then
    print -u2 "rbw: vault locked; unlocking"
    rbw unlock </dev/tty >/dev/tty 2>/dev/tty && rbw unlocked >/dev/null 2>&1
    return
  fi

  return 1
}

_rbw_ssh_auth_sock() {
  local lib="${ENV_DIR:-${ENV_NEXT_DIR:-$HOME/.config/env}}/lib/rbw-sock.sh"
  [[ -r "$lib" ]] || return 1
  source "$lib"
  if [[ "$OSTYPE" == darwin* ]]; then
    env_next_rbw_sock_darwin
  else
    env_next_rbw_sock_linux
  fi
}

_rbw_fix_ssh_auth_sock() {
  case "${SSH_AUTH_SOCK:-}" in
    ''|/var/run/com.apple.launchd.*/Listeners)
      local rbw_sock
      rbw_sock=$(_rbw_ssh_auth_sock) || return 1
      export SSH_AUTH_SOCK="$rbw_sock"
      ;;
  esac
}

_rbw_ssh_agent_available() {
  _rbw_fix_ssh_auth_sock || return 1
  [[ -S "${SSH_AUTH_SOCK:-}" ]] || return 1
  ssh-add -l >/dev/null 2>&1
}

_rbw_ssh_agent_ready() {
  _rbw_ssh_agent_available && return 0
  { _rbw_available && _rbw_can_prompt; } || { print -u2 "rbw: SSH agent unavailable; run 'rbw unlock' in an interactive shell"; return 1; }
  _rbw_unlock_if_needed && _rbw_ssh_agent_available && return 0
  print -u2 "rbw: SSH agent unreachable at ${SSH_AUTH_SOCK:-<unset>}"; return 1
}

_rbw_get_or_unlock() {
  local item=$1 val
  _rbw_unlock_if_needed || return 1
  val=$(rbw get "$item" 2>/dev/null) || return 1

  [[ -n $val ]] || return 1
  print -n "$val"
}

_lazy_secret() {
  local var=$1 item=$2
  if [[ -z ${(P)var} ]]; then
    local val
    val=$(_rbw_get_or_unlock "$item") || {
      print -u2 "rbw: could not retrieve '$item' for $var; vault may be locked, item may be missing, or rbw auth may need attention"
      return 1
    }
    typeset -gx "$var=$val"
  fi
}

hf_key()       { _lazy_secret HF_TOKEN          hf-token; }
context7_key() { _lazy_secret CONTEXT7_API_KEY  context7-api-key; }
pocket_id_key()   { _lazy_secret POCKET_ID_API_KEY    pocket-id-api-key; }
h_cloud_age_key() { _lazy_secret SOPS_AGE_KEY    h-cloud-age-key; }

_rbw_env() {
  local wrapper="${ENV_DIR:-${ENV_NEXT_DIR:-$HOME/.config/env}}/bin/rbw-env"
  if [[ -x "$wrapper" ]]; then
    "$wrapper" "$@"
  else
    print -u2 "rbw-env: wrapper unavailable"
    return 127
  fi
}

sops() {
  _rbw_env sops -- command sops "$@"
}

(( $+commands[rbw] )) || return 0

git() {
  case "${1:-}" in
    commit|tag|merge|push|pull|fetch|clone|ls-remote|submodule)
      if (( ! ${+compstate} )) && _rbw_can_prompt; then
        case $1 in
          commit|tag|merge) _rbw_unlock_if_needed || return ;;
          *) _rbw_ssh_agent_ready || return ;;
        esac
      else
        _rbw_fix_ssh_auth_sock >/dev/null 2>&1
      fi
      ;;
  esac
  command git "$@"
}
