# --- git --------------------------------------------------------------------
gupf() {
  [[ -n $1 ]] || { echo "Usage: gupf <commit-message>" >&2; return 1; }
  git reset head^1 && git add . && git commit -m "$1" && git push -f
}

# Ensure rbw is unlocked before signing operations so GPG can fetch the key.
git() {
  case "${1:-}" in
    commit|tag|merge)
      rbw unlocked 2>/dev/null || rbw unlock
      ;;
  esac
  command git "$@"
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

# --- herdr ------------------------------------------------------------------
herdr() {
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
  local repo="${DOTFILES_DIR:-$HOME/Dev/dotfiles}"
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

# --- macOS session recovery -------------------------------------------------
fix-secure-input() {
  emulate -L zsh

  if [[ "${1:-}" != "--yes" ]]; then
    print "fix-secure-input: this logs out of the macOS GUI session."
    printf "Continue? [y/N] "
    local reply
    read -r reply
    [[ $reply == [yY]* ]] || { print "fix-secure-input: aborted"; return 1; }
  fi

  osascript -e 'tell application "System Events" to log out'
}
alias fix-skhd='fix-secure-input'

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


swap-keys() {
  hidutil property --set '{

  "UserKeyMapping": [
    {
      "HIDKeyboardModifierMappingSrc": 0x700000064,
      "HIDKeyboardModifierMappingDst": 0x700000035
      },
      {
      "HIDKeyboardModifierMappingSrc": 0x700000035,
      "HIDKeyboardModifierMappingDst": 0x700000064
      }
    ]
  }'  
}


# --- Default gitignore init ---------------------------------------------
gii() {
  cat > .gitignore <<'EOF'
# Secrets
./secrets/

# General
.DS_Store
.AppleDouble
.LSOverride

# Icon must end with two \r
Icon

# Thumbnails
._*

# Files that might appear in the root of a volume
.DocumentRevisions-V100
.fseventsd
.Spotlight-V100
.TemporaryItems
.Trashes
.VolumeIcon.icns
.com.apple.timemachine.donotpresent

# Directories potentially created on remote AFP share
.AppleDB
.AppleDesktop
Network Trash Folder
Temporary Items
.apdisk

*~

# temporary files which can be created if a process still has a handle open of a deleted file
.fuse_hidden*

# KDE directory preferences
.directory

# Linux trash folder which might appear on any partition or disk
.Trash-*

# .nfs files are created when an open file is removed but is still being accessed
.nfs*

# Windows thumbnail cache files
Thumbs.db
Thumbs.db:encryptable
ehthumbs.db
ehthumbs_vista.db

# Dump file
*.stackdump

# Folder config file
[Dd]esktop.ini

# Recycle Bin used on file shares
$RECYCLE.BIN/

# Windows Installer files
*.cab
*.msi
*.msix
*.msm
*.msp

# Windows shortcuts
*.lnk

# VSCode
.vscode/*
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
!.vscode/*.code-snippets
.history/
*.vsix

# Vim swap
[._]*.s[a-v][a-z]
!*.svg
[._]*.sw[a-p]
[._]s[a-rt-v][a-z]
[._]ss[a-gi-z]
[._]sw[a-p]
Session.vim
Sessionx.vim
.netrwhist
tags
[._]*.un~

# JetBrains IDEs (IntelliJ, GoLand, PyCharm, WebStorm, etc.)
.idea/
*.iml
*.iws
*.ipr
out/
.idea_modules/

# Zed
.zed/

# Sublime Text
*.sublime-project
*.sublime-workspace

# Emacs
\#*\#
.\#*
.emacs.desktop
.emacs.desktop.lock
auto-save-list
tramp

# Nano
*.save

# AI local state
CLAUDE.local.md
.claude/settings.local.json
.sisyphus/
.omc/
**/.wolf/
.leankg/
GEMINI.local.md
.aider.chat.history.md
.aider.input.history
.aider.tags.cache.v*
.aider.repo.map
.copilot/
.codeium/
.augment/
.kiro/
.tabnine/
.amp/
.qodo/

# Environment files
.env
.env.*
!.env.example
!.env.sample
.envrc
.direnv/

# SSH / secret material
*.pem
*.key
id_rsa
id_ed25519
EOF
}
