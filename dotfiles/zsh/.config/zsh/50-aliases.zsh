# ls
alias la='ls -lah'
alias lh=la
alias ll='ls -lh'

alias cat='bat'

alias or='omni reconcile -y'

if ! command -v terraform >/dev/null 2>&1 && command -v tofu >/dev/null 2>&1; then
  alias terraform='tofu'
fi

#github
alias gh="GITHUB_TOKEN= command gh"
# git
ga() { git add "${@:-.}"; }

# Table-driven completion: complete an alias as if typing its base command.
typeset -gA _subcmd_base=(ga 'git add' fxr 'flux reconcile')
_subcmd_complete() {
  local base=(${=_subcmd_base[$words[1]]}) w=("${words[@]}") c=$CURRENT
  words=($base "${w[2,-1]}"); (( CURRENT = c + ${#base} - 1 ))
  (( $+functions[_${base[1]}] )) && _${base[1]} || _default
  local st=$?; words=("${w[@]}"); CURRENT=$c; return $st
}
(( $+functions[compdef] )) && compdef _subcmd_complete ga fxr
alias gcm='git commit -m'
alias gco='git checkout'
alias gl="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n'' %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --all"
alias glg='git log --decorate --pretty=oneline --abbrev-commit'
alias gpf='git push --force-with-lease'
alias gpl='git pull'
alias gf='git fetch'
alias gp='git push'
alias gr='git reset'
alias grs='git restore'
alias grbd='git rebase origin/develop'
alias grbm='git rebase origin/master'
alias gs='git status'
alias gd='git diff'
alias gu='git fetch && git pull'

# kubernetes
alias k='kubectl '
alias ke='kubectl edit '
alias kecm='kubectl edit configmap '
alias ked='kubectl edit deployments '
alias kep='kubectl edit pods '
alias kg='kubectl get '
alias kgd='kubectl get deployments '
alias kgn='kubectl get nodes '
alias kgp='kubectl get pods '
alias kgj='kubectl get jobs.batch '
alias kgcj='kubectl get cronjobs.batch '
alias kgb='kubectl get backups '
alias kgbo='kubectl get backups -o yaml -w '
alias kghs='kubectl get hanaservices '
alias kgho='kubectl get hanas -o yaml -w '
alias kghso='kubectl get hanaservices -o yaml -w '
alias kgs='kubectl get services '
alias kd='kubectl describe '
alias kdn='kubectl describe nodes '
alias kdp='kubectl describe pod '
alias kdj='kubectl describe jobs.batch '
alias kdd='kubectl describe deployments '
alias kdcj='kubectl describe cronjobs.batch '
alias kds='kubectl describe services '
alias kdl='kubectl delete '
alias kdld='kubectl delete deployments '
alias kdlp='kubectl delete pods '
alias kdln='kubectl delete nodes '
alias kl='kubectl logs -f '
alias ktx='kubectx '

# flux kustomize/helm
alias kdk='kubectl describe kustomizations.kustomize.toolkit.fluxcd.io '
alias kdh='kubectl describe helmreleases.helm.toolkit.fluxcd.io '
alias kgk='kubectl get kustomizations.kustomize.toolkit.fluxcd.io '
alias kgh='kubectl get helmreleases.helm.toolkit.fluxcd.io '

# talos
alias tc='talosctl '
alias tcg='talosctl get '
function tcd {
  talosctl -n "k8s-$1" dashboard
}

# flux
alias fx='flux '
function fxr {
  flux reconcile "$@" --with-source
}

# woodpecker
alias wp='woodpecker-cli '

# agents
alias cr='coder '
alias crs='coder ssh '
alias cru='coder update '
alias crr='coder restart '
function crur {
  coder update "$@"
  coder restart "$@" --yes
}
