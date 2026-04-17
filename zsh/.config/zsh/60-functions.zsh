# --- git --------------------------------------------------------------------
gupf() {
  git reset head^1 && git add . && git commit -m "$1" && git push -f
}

# --- k8s helpers ------------------------------------------------------------
kgpn() {
  kubectl get pods --all-namespaces --field-selector spec.nodeName="$1"
}

# kubectl exec into a pod by label
# Usage: ksh <namespace> <app-label>
ksh() {
  local ns=$1 app=$2
  kubectl exec -it -n "$ns" \
    "$(kubectl get pods -n "$ns" -l app="$app" -o jsonpath='{.items[0].metadata.name}')" \
    -- sh -c "bash || sh"
}

# temporary busybox shell in a namespace
csh() {
  local ns=$1
  kubectl run -it --rm --restart=Never --image=busybox tmp-shell -n "$ns" -- sh
}

# --- ssh wrapper — set terminal title, use ~/.config/ssh/config -------------
ssh() {
  local target user host
  for arg in "$@"; do
    [[ "$arg" != -* ]] && target="$arg"
  done
  if [[ "$target" == *"@"* ]]; then
    user="${target%@*}"; host="${target#*@}"
  else
    user="$USER"; host="$target"
  fi
  printf '\033]2;%s@%s\007' "$user" "$host"
  command ssh -F "$HOME/.config/ssh/config" "$@"
}

dotsync() {
  bash "${DOTFILES_DIR:-$HOME/Dev/dotfiles}/scripts/sync.sh" "$@"
}

# --- brew wrapper: refresh yabai sudoers after install/upgrade --------------
# yabai's --load-sa sudoers entry pins the binary's SHA256, so it must be
# rewritten after any brew action that may have replaced the yabai binary.
# Wrapping `brew` itself catches every path: `bu`, `brew upgrade yabai`,
# `brew bundle`, `brew install yabai`, …
brew() {
  local pre_hash="" post_hash="" yabai_path
  case "${1:-}" in
    install|upgrade|reinstall|bundle)
      yabai_path=$(command -v yabai 2>/dev/null) || true
      [[ -n "$yabai_path" ]] && pre_hash=$(shasum -a 256 "$yabai_path" 2>/dev/null | cut -d' ' -f1)
      ;;
  esac

  command brew "$@"
  local rc=$?

  case "${1:-}" in
    install|upgrade|reinstall|bundle)
      yabai_path=$(command -v yabai 2>/dev/null) || true
      [[ -n "$yabai_path" ]] && post_hash=$(shasum -a 256 "$yabai_path" 2>/dev/null | cut -d' ' -f1)
      local script="$HOME/.config/yabai/update_sudoers.sh"
      if [[ -n "$post_hash" && -x "$script" ]]; then
        # Binary changed (install or upgrade) → refresh sudoers + warn about SIP
        if [[ "$pre_hash" != "$post_hash" ]]; then
          print -u2 ""
          print -u2 "\033[33m── yabai binary changed — refreshing sudoers entry ──\033[0m"
          "$script"
          # SIP must be partially disabled for --load-sa to actually load
          if command -v csrutil >/dev/null 2>&1; then
            local sip_status
            sip_status=$(csrutil status 2>/dev/null)
            if [[ "$sip_status" != *"disabled"* && "$sip_status" != *"Custom Configuration"* ]]; then
              print -u2 ""
              print -u2 "\033[33m! yabai --load-sa requires SIP partially disabled.\033[0m"
              print -u2 "\033[33m  Boot to recovery → Terminal:\033[0m"
              print -u2 "\033[33m  csrutil disable --with-kext --with-dtrace --with-nvram --with-basesystem\033[0m"
            fi
          fi
        # Binary unchanged but sudoers drifted (e.g. first install) → quiet refresh
        elif ! "$script" --check --quiet; then
          print -u2 "yabai: sudoers entry stale — refreshing"
          "$script"
        fi
      fi
      ;;
  esac
  return $rc
}

vaulttoken() {
  echo "$1" > "$HOME/.vault-token"
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
