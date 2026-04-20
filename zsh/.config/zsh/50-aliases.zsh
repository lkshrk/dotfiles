# ls
alias la='ls -lah'
alias lh=la
alias ll='ls -lh'

# brew — note: `brew` itself is wrapped in 60-functions.zsh to refresh
# the yabai sudoers entry after install/upgrade/reinstall/bundle.
alias bupgrade='brew list --cask | xargs brew upgrade --cask'
alias bu='brew update && brew upgrade'

# flux
alias fr='flux reconcile '

# git
function ga { [[ $# -eq 0 ]] && git add . || git add "$@"; }
alias gcm='git commit -m'
alias gco='git checkout'
alias gl="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n'' %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --all"
alias glg='git log --decorate --pretty=oneline --abbrev-commit'
alias gpf='git push -f'
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
alias gup='git reset head^1 && git add . && git commit -m'

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
alias kgbo='kubectl get backups -o yaml -w'
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
alias kl='kubectl logs -f'
alias ktx='kubectx '

# flux kustomize/helm
alias kdk='kubectl describe kustomizations.kustomize.toolkit.fluxcd.io '
alias kdh='kubectl describe helmreleases.helm.toolkit.fluxcd.io '
alias kgk='kubectl get kustomizations.kustomize.toolkit.fluxcd.io '
alias kgh='kubectl get helmreleases.helm.toolkit.fluxcd.io '

# talos
alias tc='talosctl '
alias tcg='talosctl get '
alias tcd='talosctl dashboard '

# opencode
alias oc='opencode --port'

# ssh — use ~/.config/ssh/config (overrides default ~/.ssh/config location)
alias scp='scp -F ~/.config/ssh/config'
alias sftp='sftp -F ~/.config/ssh/config'
