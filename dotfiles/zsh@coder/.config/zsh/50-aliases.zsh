alias la='ls -lah'
alias lh='ls -lah'
alias ll='ls -lh'

alias or='omni reconcile -y'
alias ots='omni tools sync --all'
alias ods='omni dots sync'

function ga() {
  if [[ $# -eq 0 ]]; then
    git add .
  else
    git add "$@"
  fi
}

alias gcm='git commit -m'
alias gco='git checkout'
alias gs='git status'

alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias kctx='kubectx'
alias kns='kubens'

alias fx='flux'
function fxr() {
  flux reconcile "$@" --with-source
}

alias tc='talosctl'
alias tcg='talosctl get'

alias cr='coder'
alias crs='coder ssh'
alias cru='coder update'
alias crr='coder restart'
function crur() {
  coder update "$@"
  coder restart "$@" --yes
}
