_vault_bin=${ENV_DIR:-$HOME/.config/env}/bin

# Exit 2 from vault-unlock: no TTY or graphical session to prompt in.
vault_unlock_if_needed() {
  [[ -x $_vault_bin/vault-unlock ]] || return 1
  "$_vault_bin/vault-unlock"
}

# Points SSH_AUTH_SOCK at the vault's agent when it is unset, launchd's, or no longer a socket.
vault_fix_ssh_auth_sock() {
  [[ -n ${SSH_AUTH_SOCK:-} && -S $SSH_AUTH_SOCK && $SSH_AUTH_SOCK != /var/run/com.apple.launchd.*/Listeners ]] && return 0
  local sock os=linux
  [[ $OSTYPE == darwin* ]] && os=darwin
  sock=$(source "${ENV_DIR:-$HOME/.config/env}/lib/ssh-agent-sock.sh" 2>/dev/null && env_agent_sock_$os) || return 1
  export SSH_AUTH_SOCK=$sock
}

lazy_secret() {
  local var=$1 item=$2 val
  [[ -z ${(P)var} ]] || return 0
  if val=$("$_vault_bin/vault-get" "$item" 2>/dev/null) && [[ -n $val ]]; then
    typeset -gx "$var=$val"
    return 0
  fi
  print -u2 "vault: could not retrieve '$item' for $var; the vault may be locked or the item missing"
  return 1
}

hf_key()          { lazy_secret HF_TOKEN          hf-token; }
context7_key()    { lazy_secret CONTEXT7_API_KEY  context7-api-key; }
pocket_id_key()   { lazy_secret POCKET_ID_API_KEY pocket-id-api-key; }
h_cloud_age_key() { lazy_secret SOPS_AGE_KEY      h-cloud-age-key; }

vault_env() { "$_vault_bin/vault-env" "$@"; }

[[ -x $_vault_bin/vault-env ]] && sops() { vault_env sops -- sops "$@"; }

# Signing (commit/tag/merge) and SSH remotes need the vault's SSH agent; the desktop app asks to unlock by itself, rbw (macOS) does not.
git() {
  # Agent shell snapshots can carry this wrapper without its helpers.
  (( $+functions[vault_fix_ssh_auth_sock] )) || { command git "$@"; return; }
  case ${1:-} in
    commit|tag|merge|push|pull|fetch|clone|ls-remote|submodule)
      vault_fix_ssh_auth_sock
      if [[ $OSTYPE == darwin* ]] && ! (( ${+compstate} )); then
        vault_unlock_if_needed || (( $? == 2 )) || return
      fi ;;
  esac
  command git "$@"
}
