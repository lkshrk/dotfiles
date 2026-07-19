#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSH_CONFIG="$REPO_DIR/dotfiles/zsh/.config/zsh/70-coder-terminal.zsh"
BASH_CONFIG="$REPO_DIR/dotfiles/bashrc@coder/.bashrc"
LOCAL_TMUX_CONFIG="$REPO_DIR/dotfiles/tmux/.config/tmux/tmux.conf"
CODER_TMUX_CONFIG="$REPO_DIR/dotfiles/tmux@coder/.config/tmux/tmux.conf"
RESOURCE_STATUS="$REPO_DIR/dotfiles/tmux@coder/.config/tmux/status-resources"

fake_bin=$(mktemp -d)
local_socket="coder-test-local-$$"
coder_socket="coder-test-remote-$$"
cleanup() {
  TMUX='' tmux -L "$local_socket" kill-server 2>/dev/null || true
  TMUX='' tmux -L "$coder_socket" kill-server 2>/dev/null || true
  rm -rf "$fake_bin"
}
trap cleanup EXIT
cat > "$fake_bin/tmux" <<'EOF'
#!/usr/bin/env sh
target=
previous=
for argument do
  [ "$previous" = -t ] && target=$argument
  previous=$argument
done
target=${target#=}
attached=
for session in ${TMUX_TEST_SESSIONS:-}; do
  case $session in
    "$target="*) attached=${session#*=} ;;
  esac
done
case $1 in
  has-session)
    [ -n "$attached" ]
    ;;
  display-message)
    printf '%s\n' "$attached"
    ;;
  *)
    printf '%s\n' "$*"
    ;;
esac
EOF
chmod +x "$fake_bin/tmux"

zsh -n "$ZSH_CONFIG"
bash -n "$BASH_CONFIG"

zsh_result=$(CODER_WORKSPACE_NAME=test TMUX=test ZSH_CONFIG="$ZSH_CONFIG" zsh -fic '
  source "$ZSH_CONFIG"
  hits=0
  _coder_clear_mouse_modes() { (( ++hits )); }
  kill -WINCH $$
  sleep 0.05
  print -r -- "$hits"
' 2>/dev/null | tail -1)
[[ "$zsh_result" == 1 ]]

check_tmux_start() {
  local sessions=$1 expected=$2 result
  result=$(PATH="$fake_bin:$PATH" CODER_WORKSPACE_NAME=test TMUX='' \
    TMUX_TEST_SESSIONS="$sessions" ZSH_CONFIG="$ZSH_CONFIG" zsh -fic \
    'source "$ZSH_CONFIG"' 2>/dev/null | tail -1)
  [[ "$result" == "$expected" ]] || {
    printf 'FAIL: expected %s, got: %s\n' "$expected" "$result" >&2
    exit 1
  }
}

check_tmux_start '' 'new-session -s default-1'
check_tmux_start 'default-1=0' 'attach-session -t =default-1'
check_tmux_start 'default-1=1' 'new-session -s default-2'
check_tmux_start 'default-1=1 default-2=0' 'attach-session -t =default-2'

printf 'cpu 100 0 100 800 0 0 0 0 0 0\n' > "$fake_bin/stat"
printf 'MemTotal: 1000 kB\nMemAvailable: 250 kB\n' > "$fake_bin/meminfo"
printf '#!/bin/sh\nprintf "%%s\\n" "Filesystem 1024-blocks Used Available Capacity Mounted on" "test 100 90 10 90%% /"\n' > "$fake_bin/df"
chmod +x "$fake_bin/df"

TMUX_RESOURCE_STAT="$fake_bin/stat" \
TMUX_RESOURCE_MEMINFO="$fake_bin/meminfo" \
TMUX_RESOURCE_STATE="$fake_bin/state" \
PATH="$fake_bin:$PATH" sh "$RESOURCE_STATUS" default-1 >/dev/null
printf 'cpu 180 0 100 820 0 0 0 0 0 0\n' > "$fake_bin/stat"
resource_result=$(TMUX_RESOURCE_STAT="$fake_bin/stat" \
  TMUX_RESOURCE_MEMINFO="$fake_bin/meminfo" \
  TMUX_RESOURCE_STATE="$fake_bin/state" \
  PATH="$fake_bin:$PATH" sh "$RESOURCE_STATUS" default-1)
[[ "$resource_result" == *'#[fg=#e0af68]▇ 80%'* ]] || exit 1
[[ "$resource_result" == *'#[fg=#e0af68]▇ 75%'* ]] || exit 1
[[ "$resource_result" == *'#[fg=#f7768e]█ 90%'* ]] || exit 1
[[ -z "$(sh "$RESOURCE_STATUS" default-2)" ]] || exit 1

bash --noprofile --norc -ic "source '$BASH_CONFIG'; trap -p WINCH" 2>/dev/null |
  grep -q _coder_clear_mouse_modes

TMUX='' tmux -L "$local_socket" -f "$LOCAL_TMUX_CONFIG" new-session -d -s check
TMUX='' tmux -L "$coder_socket" -f "$CODER_TMUX_CONFIG" new-session -d -s check

[[ "$(TMUX='' tmux -L "$local_socket" show-options -gv prefix)" == C-Space ]]
[[ "$(TMUX='' tmux -L "$local_socket" show-options -gv prefix2)" == None ]]
[[ "$(TMUX='' tmux -L "$coder_socket" show-options -gv prefix)" == C-b ]]
[[ "$(TMUX='' tmux -L "$coder_socket" show-options -gv prefix2)" == None ]]
local_wheel_binding=$(TMUX='' tmux -L "$local_socket" list-keys |
  grep -E '^bind-key +(-r +)?-T root +WheelUpPane ')
[[ "$local_wheel_binding" == *'#{||:#{pane_in_mode},#{mouse_any_flag}}'* ]]
[[ "$local_wheel_binding" != *alternate_on* ]]

[[ "$(TMUX='' tmux -L "$local_socket" show-options -sv extended-keys)" == on ]]
[[ "$(TMUX='' tmux -L "$local_socket" show-options -sv extended-keys-format)" == csi-u ]]
[[ "$(TMUX='' tmux -L "$local_socket" show-options -gv mouse)" == on ]]
[[ "$(TMUX='' tmux -L "$coder_socket" show-options -sv extended-keys)" == off ]]
[[ "$(TMUX='' tmux -L "$coder_socket" show-options -gv mouse)" == on ]] || exit 1
[[ "$(TMUX='' tmux -L "$coder_socket" show-options -gv status-right)" == *'status-resources #S'* ]] || exit 1

for key in q h v x t r c k R C K P N; do
  local_binding=$(TMUX='' tmux -L "$local_socket" list-keys |
    grep -E "^bind-key +(-r +)?-T prefix +$key " |
    sed -E 's/[[:space:]]+/ /g')
  coder_binding=$(TMUX='' tmux -L "$coder_socket" list-keys |
    grep -E "^bind-key +(-r +)?-T prefix +$key " |
    sed -E 's/[[:space:]]+/ /g')
  [[ "$local_binding" == "$coder_binding" ]]
done

printf 'PASS: Coder shells and tmux profile behave as expected\n'
