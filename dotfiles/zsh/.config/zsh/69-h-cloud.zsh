(( $+commands[rbw] )) || return 0

zmodload -F zsh/datetime p:EPOCHSECONDS

_h_cloud_script="$HOME/Dev/h-cloud/scripts/cluster-auth.sh"

h_cloud_auth() {
  local exports others=${KUBECONFIG:-} kube=${_H_CLOUD_KUBECONFIG:-}
  # Re-run the script (which renews expiring certs) at most hourly per shell.
  [[ -n $kube && -s ${TALOSCONFIG:-} && -s $kube && :$others: == *:$kube:* ]] \
    && (( ${_H_CLOUD_AUTH_AT:-0} > EPOCHSECONDS - 3600 )) && return 0
  # Tab completion must never block on an rbw/pinentry prompt.
  (( ${+compstate} )) && return 0
  rbw_unlock_if_needed || { print -u2 "h-cloud: rbw locked"; return 1; }
  exports=$("$_h_cloud_script" env) || return 1
  eval "$exports"
  typeset -g _H_CLOUD_AUTH_AT=$EPOCHSECONDS _H_CLOUD_KUBECONFIG=$KUBECONFIG
  others=${${others//$KUBECONFIG/}##:}
  others=${others%%:}
  [[ -z $others ]] || export KUBECONFIG="$KUBECONFIG:$others"
}

if [[ -x $_h_cloud_script ]]; then
  # A failed auth only warns, so contexts outside h-cloud keep working.
  for _cmd in talosctl kubectl flux helm helmfile k9s; do
    (( $+commands[$_cmd] )) || continue
    eval "$_cmd() { h_cloud_auth || print -u2 'h-cloud: no cluster credentials; other contexts only'; command $_cmd \"\$@\"; }"
  done
  unset _cmd
fi

just() {
  if [[ $PWD == $HOME/Dev/h-cloud(|/*) && ${1:-} == (talos|bootstrap|kube) ]]; then
    h_cloud_auth || return
  fi
  command just "$@"
}
