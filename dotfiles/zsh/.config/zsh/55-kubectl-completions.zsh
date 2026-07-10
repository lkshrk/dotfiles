# Wire local kubectl shortcuts to kubectl's generated completion.
_kubectl_shortcut_complete() {
  local -a _saved_words _prefix
  local _saved_current _status

  _prefix=("${@}")
  _saved_words=("${words[@]}")
  _saved_current=$CURRENT

  words=("${_prefix[@]}" "${_saved_words[2,-1]}")
  (( CURRENT = _saved_current + ${#_prefix[@]} - 1 ))

  if (( $+functions[_kubectl] )); then
    _kubectl
    _status=$?
  else
    _default
    _status=$?
  fi

  words=("${_saved_words[@]}")
  CURRENT=$_saved_current
  return $_status
}

_kubectl_complete_root() { _kubectl_shortcut_complete kubectl; }
_kubectl_complete_get() { _kubectl_shortcut_complete kubectl get; }
_kubectl_complete_describe() { _kubectl_shortcut_complete kubectl describe; }
_kubectl_complete_edit() { _kubectl_shortcut_complete kubectl edit; }
_kubectl_complete_delete() { _kubectl_shortcut_complete kubectl delete; }
_kubectl_complete_logs() { _kubectl_shortcut_complete kubectl logs -f; }

if (( $+functions[compdef] )); then
  compdef _kubectl_complete_root k
  compdef _kubectl_complete_get kg kgd kgn kgp kgj kgcj kgb kgbo kghs kgho kghso kgs
  compdef _kubectl_complete_describe kd kdn kdp kdj kdd kdcj kds kdk kdh
  compdef _kubectl_complete_edit ke kecm ked kep
  compdef _kubectl_complete_delete kdl kdld kdlp kdln
  compdef _kubectl_complete_logs kl
fi
