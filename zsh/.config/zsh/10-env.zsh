export EDITOR=nvim
export HOMEBREW_NO_ENV_HINTS=1

export GOPATH=$HOME/go
export NVM_DIR="$HOME/.nvm"
export BUN_INSTALL="$HOME/.bun"
export PNPM_HOME="$HOME/Library/pnpm"

export KUBECONFIG=$HOME/.kube/hcloud:$HOME/.kube/legacy

# SSH agent provided by rbw (Bitwarden CLI)
export SSH_AUTH_SOCK="${TMPDIR:-/tmp}/rbw-$(id -u)/ssh-agent-socket"

# Window title: "folder" locally, "host:folder" over SSH
_update_title() {
  local title="${PWD##*/}"
  [[ -n $SSH_CONNECTION ]] && title="${HOST%%.*}:$title"
  printf '\033]2;%s\007' "$title"
}
precmd_functions+=(_update_title)
chpwd_functions+=(_update_title)

# Window title: "folder" locally, "host:folder" over SSH
_update_title() {
  local title="${PWD##*/}"
  [[ -n $SSH_CONNECTION ]] && title="${HOST%%.*}:$title"
  printf '\033]2;%s\007' "$title"
}
precmd_functions+=(_update_title)
chpwd_functions+=(_update_title)
