# --- git --------------------------------------------------------------------
gupf() {
  [[ -n $1 ]] || { echo "Usage: gupf <commit-message>" >&2; return 1; }
  git reset head^1 && git add . && git commit -m "$1" && git push -f
}

# release <major|minor|patch|vX.Y.Z>
#   1. if uncommitted changes → prompt to stage+commit
#   2. tag (bumped from latest semver tag, or explicit), push branch + tag
release() {
  emulate -L zsh
  setopt local_options err_return pipe_fail

  local choice=$1
  [[ -n $choice ]] || {
    echo "Usage: release <major|minor|patch|vX.Y.Z>" >&2
    return 1
  }

  git rev-parse --git-dir >/dev/null 2>&1 || {
    echo "release: not a git repo" >&2
    return 1
  }

  local branch
  branch=$(git symbolic-ref --quiet --short HEAD) || {
    echo "release: detached HEAD, refusing" >&2
    return 1
  }

  # 1. uncommitted check
  if [[ -n "$(git status --porcelain)" ]]; then
    git status --short
    printf 'Uncommitted changes. Commit them now? [y/N] '
    local reply; read -r reply
    [[ $reply == [yY]* ]] || { echo "release: aborted" >&2; return 1; }
    printf 'Commit message: '
    local msg; read -r msg
    [[ -n $msg ]] || { echo "release: empty message" >&2; return 1; }
    git add -A
    git commit -m "$msg"
  fi

  # 2. determine new version
  local last new
  last=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)
  [[ -z $last ]] && last="v0.0.0"

  if [[ $choice == v[0-9]*.[0-9]*.[0-9]* ]]; then
    new=$choice
  else
    local clean=${last#v}
    local major=${clean%%.*}
    local rest=${clean#*.}
    local minor=${rest%%.*}
    local patch=${rest#*.}
    case $choice in
      major) new="v$((major + 1)).0.0" ;;
      minor) new="v${major}.$((minor + 1)).0" ;;
      patch) new="v${major}.${minor}.$((patch + 1))" ;;
      *) echo "release: unknown choice '$choice'" >&2; return 1 ;;
    esac
  fi

  echo "Last tag: $last → $new (branch $branch)"
  printf 'Proceed? [y/N] '
  local confirm; read -r confirm
  [[ $confirm == [yY]* ]] || { echo "release: aborted" >&2; return 1; }

  git tag -a "$new" -m "Release $new"
  git push origin "$branch"
  git push origin "$new"
  echo "release: pushed $new on $branch"
}

# --- k8s helpers ------------------------------------------------------------
kgpn() {
  [[ -n $1 ]] || { echo "Usage: kgpn <node-name>" >&2; return 1; }
  kubectl get pods --all-namespaces --field-selector spec.nodeName="$1"
}

# kubectl exec into a pod by label
# Usage: ksh <namespace> <app-label>
ksh() {
  local ns=$1 app=$2
  [[ -n $ns && -n $app ]] || { echo "Usage: ksh <namespace> <app-label>" >&2; return 1; }
  kubectl exec -it -n "$ns" \
    "$(kubectl get pods -n "$ns" -l app="$app" -o jsonpath='{.items[0].metadata.name}')" \
    -- sh -c "bash || sh"
}

# temporary busybox shell in a namespace
csh() {
  local ns=$1
  [[ -n $ns ]] || { echo "Usage: csh <namespace>" >&2; return 1; }
  kubectl run -it --rm --restart=Never --image=busybox tmp-shell -n "$ns" -- sh
}

# --- ssh wrapper — use ~/.config/ssh/config ----------------------------------
# Title is set by LocalCommand in ssh config.
ssh() { command ssh -F "$HOME/.config/ssh/config" "$@"; }

# Show repo drift + new $HOME files that are not gitignored.
dotcheck() {
  bash "${DOTFILES_DIR:-$HOME/Dev/dotfiles}/scripts/drift-check.sh" --list "$@"
}

# Start tracking a $HOME file: moves it into the repo and restows.
# Usage: dottrack ~/.config/aerospace/aerospace.toml [package]
dottrack() {
  bash "${DOTFILES_DIR:-$HOME/Dev/dotfiles}/scripts/track.sh" "$@"
}

# --- brew wrapper: refresh yabai sudoers after install/upgrade --------------
# yabai's --load-sa sudoers entry pins the binary's SHA256. After any brew
# action that could have replaced the yabai binary (install / upgrade /
# reinstall / bundle), invoke update_sudoers.sh. The script is idempotent —
# no sudo prompt, no output when the hash is already current.
brew() {
  command brew "$@"
  local rc=$?

  case "${1:-}" in
    install|upgrade|reinstall|bundle)
      local script="$HOME/.config/yabai/update_sudoers.sh"
      [[ -x "$script" ]] || return $rc
      command -v yabai >/dev/null 2>&1 || return $rc
      local out
      out=$("$script" 2>&1) || true
      [[ -n "$out" ]] || return $rc
      print -u2 ""
      print -u2 "\033[33m$out\033[0m"
      if command -v csrutil >/dev/null 2>&1; then
        local sip_status
        sip_status=$(csrutil status 2>/dev/null)
        if [[ "$sip_status" != *"disabled"* && "$sip_status" != *"Custom Configuration"* ]]; then
          print -u2 "\033[33m! yabai --load-sa requires SIP partially disabled.\033[0m"
          print -u2 "\033[33m  Boot to recovery → Terminal:\033[0m"
          print -u2 "\033[33m  csrutil disable --with-kext --with-dtrace --with-nvram --with-basesystem\033[0m"
        fi
      fi
      ;;
  esac
  return $rc
}

vaulttoken() {
  (umask 077 && print -rn -- "$1" > "$HOME/.vault-token")
}

# --- tmux dev layout --------------------------------------------------------
tdl() {
  [[ -z $1 ]] && { echo "Usage: tdl <ai> [<second_ai>]"; return 1; }
  [[ -z $TMUX ]] && { echo "tdl: must be run inside tmux"; return 1; }

  local current_dir="${PWD}"
  local editor_pane ai_pane ai2_pane
  local ai="$1" ai2="$2"

  editor_pane="$TMUX_PANE"
  tmux rename-window -t "$editor_pane" "$(basename "$current_dir")"
  tmux split-window -v -p 15 -t "$editor_pane" -c "$current_dir"
  ai_pane=$(tmux split-window -h -p 30 -t "$editor_pane" -c "$current_dir" -P -F '#{pane_id}')
  if [[ -n $ai2 ]]; then
    ai2_pane=$(tmux split-window -v -t "$ai_pane" -c "$current_dir" -P -F '#{pane_id}')
    tmux send-keys -t "$ai2_pane" "$ai2" C-m
  fi
  tmux send-keys -t "$ai_pane" "$ai" C-m
  tmux send-keys -t "$editor_pane" "$EDITOR ." C-m
  tmux select-pane -t "$editor_pane"
}

# --- moshi: attach-or-create tmux session for a project dir -----------------
moshi() {
  local dir="${1:-$PWD}"
  [[ -d "$dir" ]] || { echo "moshi: not a directory: $dir" >&2; return 1; }

  local abs session
  abs="$(cd "$dir" && pwd)"
  session="$(basename "$abs" | tr -cs '[:alnum:]_-' '-')"
  session="${session#-}"; session="${session%-}"
  [[ -n "$session" ]] || session="main"

  if ! tmux has-session -t "$session" 2>/dev/null; then
    tmux new-session -d -s "$session" -c "$abs" -n agent
    tmux new-window -t "$session":2 -c "$abs" -n review
    tmux new-window -t "$session":3 -c "$abs" -n tests
    tmux new-window -t "$session":4 -c "$abs" -n servers
    tmux new-window -t "$session":5 -c "$abs" -n misc
  fi
  tmux attach -t "$session"
}

# --- ai-clean: wipe coding-agent caches, show freed space -----------------
ai-clean() {
  local dirs=(
    ~/.claude/{cache,logs,file-history,shell-snapshots,statsig,todos}
    ~/.codex/{tmp,log,cache,sessions,history,artifacts}
    ~/.cache/{opencode,aider,Cursor,Windsurf,Code}
  )
  local -a targets=()
  for d in $dirs; do
    [[ -d "$d" ]] && targets+=("$d")
  done
  (( ${#targets} )) || { print "ai-clean: nothing to clean"; return 0; }

  local before after freed
  before=$(du -sc "${targets[@]}" 2>/dev/null | tail -1 | awk '{print $1}')
  rm -rf "${targets[@]}"/* 2>/dev/null
  after=$(du -sc "${targets[@]}" 2>/dev/null | tail -1 | awk '{print $1}')
  freed=$(( (before - after) / 1024 ))
  print "ai-clean: freed ${freed}MB (files)"

  if command -v docker &>/dev/null && docker info &>/dev/null; then
    local reclaimed
    reclaimed=$(docker system prune -af --volumes 2>/dev/null | grep -i 'reclaimed' | grep -oE '[0-9.]+[kMGT]B')
    print "ai-clean: docker pruned${reclaimed:+ $reclaimed}"
  fi
}


# --- Default gitignore init ---------------------------------------------
gii() {
  gibo dump VSCode JetBrains Vim Neovim Emacs SublimeText VisualStudio Zed \
    macOS Linux Windows llm claude
}
