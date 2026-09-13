#!/usr/bin/env bash

c_red=$'\033[31m'
c_yel=$'\033[33m'
c_grn=$'\033[32m'
c_dim=$'\033[2m'
c_off=$'\033[0m'

say()  { printf '%b\n' "$*"; }
step() { say "${c_dim}==>${c_off} $*"; }
ok()   { say "${c_grn}OK${c_off} $*"; }
warn() { say "${c_yel}!${c_off} $*"; }
die()  { say "${c_red}x${c_off} $*" >&2; exit 1; }

install_coder_workspace_notes() {
  local target temporary docker_note
  local -a targets=("$@")
  case "${CODER_ENABLE_DIND:-0}" in
    1) docker_note='- Docker is available through Docker-in-Docker (DinD).' ;;
    0) docker_note='- Docker-in-Docker (DinD) is not enabled. Do not assume a Docker daemon is available.' ;;
    *) warn "CODER_ENABLE_DIND must be 0 or 1"; return 1 ;;
  esac
  for target in "${targets[@]}"; do
    [[ -f "$target" ]] || {
      warn "workspace instructions not found: $target"
      continue
    }
    temporary="$(mktemp "$(dirname "$target")/.coder-notes.XXXXXX")"
    if ! awk -v docker="$docker_note" '
      function block() {
        print "<!-- coder-workspace:start -->"
        print "## Coder workspace\n"
        print docker
        print "- Git SSH operations must preserve and use the existing `$GIT_SSH_COMMAND`. Do not unset, replace, or bypass it."
        print "<!-- coder-workspace:end -->"
      }
      /^<!-- coder-workspace:start -->$/ {
        if (!found++) block()
        inside = 1
        next
      }
      /^<!-- coder-workspace:end -->$/ { inside = 0; next }
      !inside { print }
      END {
        if (inside) exit 1
        if (!found) { print ""; block() }
      }
    ' "$target" > "$temporary"; then
      rm -f "$temporary"
      warn "unterminated Coder workspace notes: $target"
      return 1
    fi
    chmod --reference="$target" "$temporary"
    mv -f "$temporary" "$target"
  done
}

install_ghostty_terminfo() {
  step "Ghostty terminfo"
  if infocmp -x xterm-ghostty >/dev/null 2>&1; then
    ok "Ghostty terminfo already installed"
    return 0
  fi

  local source="$REPO_DIR/assets/terminfo/xterm-ghostty.terminfo"
  [[ -r "$source" ]] || {
    warn "Ghostty terminfo source missing; continuing setup"
    return 0
  }
  command -v tic >/dev/null 2>&1 || {
    warn "tic not found; continuing setup"
    return 0
  }

  mkdir -p "$HOME/.terminfo"
  tic -x -o "$HOME/.terminfo" "$source" >/dev/null 2>&1 || {
    warn "Ghostty terminfo install failed; continuing setup"
    return 0
  }
  TERMINFO="$HOME/.terminfo" infocmp -x xterm-ghostty >/dev/null 2>&1 || {
    warn "Ghostty terminfo verification failed; continuing setup"
    return 0
  }
  ok "Ghostty terminfo installed"
}

