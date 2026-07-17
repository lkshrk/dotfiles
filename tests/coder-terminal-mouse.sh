#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSH_CONFIG="$REPO_DIR/dotfiles/zsh/.config/zsh/70-coder-terminal.zsh"
BASH_CONFIG="$REPO_DIR/dotfiles/bashrc@coder/.bashrc"

zsh -n "$ZSH_CONFIG"
bash -n "$BASH_CONFIG"

zsh_result=$(CODER_WORKSPACE_NAME=test ZSH_CONFIG="$ZSH_CONFIG" zsh -fic '
  source "$ZSH_CONFIG"
  hits=0
  _coder_clear_mouse_modes() { (( ++hits )); }
  kill -WINCH $$
  sleep 0.05
  print -r -- "$hits"
' 2>/dev/null | tail -1)
[[ "$zsh_result" == 1 ]]

bash --noprofile --norc -ic "source '$BASH_CONFIG'; trap -p WINCH" 2>/dev/null |
  grep -q _coder_clear_mouse_modes

printf 'PASS: Coder shells clear stale mouse modes on WINCH\n'
