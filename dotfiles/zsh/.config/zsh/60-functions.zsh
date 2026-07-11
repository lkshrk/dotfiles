# --- git --------------------------------------------------------------------
gupf() {
  [[ -n $1 ]] || { echo "Usage: gupf <commit-message>" >&2; return 1; }
  git add -A && git commit --amend -m "$1" && git push --force-with-lease
}

gup() {
  [[ -n $1 ]] || { echo "Usage: gup <commit-message>" >&2; return 1; }
  git add -A && git commit --amend -m "$1"
}

# release <major|minor|patch|vX.Y.Z>
#   1. if uncommitted changes -> prompt to stage+commit
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
  git fetch --tags --quiet
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

  echo "Last tag: $last -> $new (branch $branch)"
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
  (( $+commands[kubectl] )) || { echo "kgpn: kubectl not found" >&2; return 127; }
  kubectl get pods --all-namespaces --field-selector spec.nodeName="$1"
}

# kubectl exec into a pod by label
# Usage: ksh <namespace> <app-label>
ksh() {
  local ns=$1 app=$2
  [[ -n $ns && -n $app ]] || { echo "Usage: ksh <namespace> <app-label>" >&2; return 1; }
  (( $+commands[kubectl] )) || { echo "ksh: kubectl not found" >&2; return 127; }
  local pod
  pod=$(kubectl get pods -n "$ns" -l app="$app" -o jsonpath='{.items[0].metadata.name}') || return
  [[ -n $pod ]] || { echo "ksh: no pod found for app=$app in namespace=$ns" >&2; return 1; }
  kubectl exec -it -n "$ns" "$pod" -- sh -c "bash || sh"
}

# temporary busybox shell in a namespace
csh() {
  local ns=$1
  [[ -n $ns ]] || { echo "Usage: csh <namespace>" >&2; return 1; }
  (( $+commands[kubectl] )) || { echo "csh: kubectl not found" >&2; return 127; }
  kubectl run -it --rm --restart=Never --image=busybox "tmp-shell-${USER:-user}-$$" -n "$ns" -- sh
}

# --- coder: login + create-from-preset + connect -----------------------------
code() {
  local -a o_cpu o_mem o_disk
  zparseopts -D -E -- -cpu:=o_cpu -memory:=o_mem -disk:=o_disk
  local preset=$1 template=${2:-$CODER_TEMPLATE}
  local -a params
  [[ -n ${o_cpu[2]} ]]  && params+=(--parameter "cpu=${o_cpu[2]}")
  [[ -n ${o_mem[2]} ]]  && params+=(--parameter "memory=${o_mem[2]}")
  [[ -n ${o_disk[2]} ]] && params+=(--parameter "disk_size=${o_disk[2]}")
  [[ -n $preset ]] || { echo "Usage: code [--cpu N] [--memory N] [--disk N] <preset> [template]" >&2; return 1; }
  (( $+commands[coder] )) || { echo "code: coder not found" >&2; return 127; }
  coder whoami &>/dev/null || coder login || return
  if ! coder show "$preset" &>/dev/null; then
    if [[ -z $template ]]; then
      local t
      for t in $(coder templates list -o json 2>/dev/null | jq -r '.[].Template.name'); do
        if coder templates presets list "$t" -o json 2>/dev/null \
             | jq -e --arg p "$preset" 'any(.[]; .TemplatePreset.Name == $p)' &>/dev/null; then
          template=$t
          break
        fi
      done
      [[ -n $template ]] || { echo "code: no template has preset '$preset'" >&2; return 1; }
    fi
    coder create "$preset" -t "$template" --preset "$preset" "${params[@]}" \
      --use-parameter-defaults -y || return
  fi
  # ssh autostarts a stopped workspace, so no explicit start needed
  coder ssh "$preset"
}

# --- herdr ------------------------------------------------------------------
herdr() {
  (( $+commands[herdr] )) || { echo "herdr: command not found" >&2; return 127; }

  local runtime_root="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
  runtime_root="${runtime_root%/}"

  local config_dir="$HOME/.config/herdr"
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr"
  command mkdir -p "$runtime_root" "$config_dir" "$state_dir" || return

  local log config_log state_log
  for log in herdr.log herdr-client.log herdr-server.log; do
    config_log="$config_dir/$log"
    state_log="$state_dir/$log"
    if [[ -e "$config_log" && ! -L "$config_log" ]]; then
      command mv "$config_log" "$state_log" || return
    fi
    [[ -e "$config_log" || -L "$config_log" ]] || command ln -s "$state_log" "$config_log" || return
  done

  HERDR_CONFIG_PATH="$HOME/.config/herdr/config.toml" \
  HERDR_SOCKET_PATH="$runtime_root/herdr.sock" \
  HERDR_CLIENT_SOCKET_PATH="$runtime_root/herdr-client.sock" \
  command herdr "$@"
}

_dotfiles_omni() {
  local repo="${DOTFILES_DIR:-}"
  if [[ -z "$repo" ]]; then
    if [[ -d "$HOME/Dev/dotfiles" ]]; then
      repo="$HOME/Dev/dotfiles"
    else
      repo="$HOME/dotfiles"
    fi
  fi
  [[ -d "$repo" ]] || {
    print -u2 "dotfiles repo not found: $repo"
    return 1
  }

  command omni --config "$repo/dotfiles/omni/.config/omni/settings.json" "$@"
}

# Sync tools, upgrades, dotfile links, and dotfile commits.
dotsync() {
  _dotfiles_omni reconcile "$@"
}

# Show dotfile symlink health and repo status.
dotcheck() {
  _dotfiles_omni dots status "$@"
}

# Start tracking a local path by adopting it into Omni dots management.
# Usage: dottrack ~/.config/aerospace/aerospace.toml [--name aerospace]
dottrack() {
  _dotfiles_omni dots add --adopt "$@"
}

vaulttoken() {
  local token="${1:-}"
  if [[ -z "$token" ]]; then
    if [[ -t 0 ]]; then
      printf "Vault token: " >&2
      IFS= read -rs token
      printf "\n" >&2
    fi
  fi
  [[ -n "$token" ]] || { echo "Usage: vaulttoken <token>" >&2; return 1; }
  (umask 077 && print -rn -- "$token" > "$HOME/.vault-token")
}

# --- tmux dev layout --------------------------------------------------------
tdl() {
  [[ -z $1 ]] && { echo "Usage: tdl <ai> [<second_ai>]"; return 1; }
  (( $+commands[tmux] )) || { echo "tdl: tmux not found" >&2; return 127; }
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
  (( $+commands[tmux] )) || { echo "moshi: tmux not found" >&2; return 127; }

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
  local confirm=0
  [[ "${1:-}" == "--yes" ]] && confirm=1

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
  print "ai-clean: targets:"
  printf '  %s\n' "${targets[@]}"
  print "ai-clean: estimated cache size $(( before / 1024 ))MB"

  if (( ! confirm )); then
    print "ai-clean: dry run only; rerun with --yes to delete files and prune Docker"
    return 0
  fi

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
  local template="$HOME/.config/zsh/templates/default.gitignore"
  [[ -r "$template" ]] || { echo "gii: template not found: $template" >&2; return 1; }
  if [[ -e .gitignore && "${1:-}" != "--force" ]]; then
    echo "gii: .gitignore exists; use gii --force to overwrite" >&2
    return 1
  fi
  cp "$template" .gitignore
}
