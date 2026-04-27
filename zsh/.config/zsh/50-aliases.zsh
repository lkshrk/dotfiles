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
function ga() {
  if [[ $# -eq 0 ]]; then
    git add .
  else
    git add "$@"
  fi
}
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

# claude — real claude with native API keys
claude() {
  (
    unset ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_BASE_URL API_TIMEOUT_MS ANTHROPIC_AUTH_TOKEN
    with-secrets \
      openai-api-key    OPENAI_API_KEY \
      zai-api-key       ZAI_API_KEY \
      hf-token          HF_TOKEN \
      context7-api-key  CONTEXT7_API_KEY \
      -- command claude "$@"
  )
}

# fcc — free-claude-code proxy
fcc() {
  (
    # Fetch all keys once into this subshell
    with-secrets \
      nvidia-api-key    NVIDIA_NIM_API_KEY \
      openrouter.ai     OPENROUTER_API_KEY \
      context7-api-key  CONTEXT7_API_KEY \
      -- true

    # Start free-claude-code proxy if not already listening
    local _fcc_pid=0
    if ! lsof -i :8082 -sTCP:LISTEN &>/dev/null; then
      free-claude-code &>/dev/null &
      _fcc_pid=$!
      local _i=0
      while ! lsof -i :8082 -sTCP:LISTEN &>/dev/null && (( _i++ < 50 )); do
        sleep 0.1
      done
      if ! lsof -i :8082 -sTCP:LISTEN &>/dev/null; then
        print -u2 "fcc: proxy failed to start on :8082"
        return 1
      fi
      print -u2 "fcc: proxy started on :8082 (pid $_fcc_pid)"
    fi

    # Kill proxy on exit if we started it
    (( _fcc_pid )) && trap "kill $_fcc_pid 2>/dev/null" EXIT

    ANTHROPIC_BASE_URL="http://localhost:8082" \
    API_TIMEOUT_MS=3000000 \
    command claude "$@"
  )
}

# claude — real claude with native API keys
claude() {
  (
    unset ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_BASE_URL API_TIMEOUT_MS ANTHROPIC_AUTH_TOKEN
    with-secrets \
      openai-api-key    OPENAI_API_KEY \
      zai-api-key       ZAI_API_KEY \
      hf-token          HF_TOKEN \
      context7-api-key  CONTEXT7_API_KEY \
      -- command claude "$@"
  )
}

# fcc — free-claude-code proxy
fcc() {
  (
    # Fetch all keys once into this subshell
    with-secrets \
      nvidia-api-key    NVIDIA_NIM_API_KEY \
      openrouter.ai     OPENROUTER_API_KEY \
      context7-api-key  CONTEXT7_API_KEY \
      -- true

    # Start free-claude-code proxy if not already listening
    local _fcc_pid=0
    if ! lsof -i :8082 -sTCP:LISTEN &>/dev/null; then
      free-claude-code &>/dev/null &
      _fcc_pid=$!
      local _i=0
      while ! lsof -i :8082 -sTCP:LISTEN &>/dev/null && (( _i++ < 50 )); do
        sleep 0.1
      done
      if ! lsof -i :8082 -sTCP:LISTEN &>/dev/null; then
        print -u2 "fcc: proxy failed to start on :8082"
        return 1
      fi
      print -u2 "fcc: proxy started on :8082 (pid $_fcc_pid)"
    fi

    # Kill proxy on exit if we started it
    (( _fcc_pid )) && trap "kill $_fcc_pid 2>/dev/null" EXIT

    ANTHROPIC_BASE_URL="http://localhost:8082" \
    API_TIMEOUT_MS=3000000 \
    command claude "$@"
  )
}

# ssh — use ~/.config/ssh/config (overrides default ~/.ssh/config location)
alias scp='scp -F ~/.config/ssh/config'
alias sftp='sftp -F ~/.config/ssh/config'
