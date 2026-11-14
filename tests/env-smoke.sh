#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
[ "$(uname -s)" = Darwin ] || exec sh "$repo/tests/env-linux-smoke.sh"

tmpdir=
node_probe_dir=
render=$(mktemp -d)
cleanup() {
  [ -z "${tmpdir:-}" ] || rm -rf "$tmpdir"
  [ -z "${node_probe_dir:-}" ] || rm -rf "$node_probe_dir"
  rm -rf "$render"
}
trap cleanup EXIT HUP INT TERM
ENV_DIR="${ENV_DIR:-$("$repo/scripts/render-home.sh" topaz "$render")/.config/env}"
export ENV_DIR

probe='
unset SSH_AUTH_SOCK
PATH=/usr/bin:/bin
. "$ENV_DIR/profile.sh"
find_command_path() {
  if command -v whence >/dev/null 2>&1; then
    whence -p "$1" 2>/dev/null || true
  else
    command -v "$1" 2>/dev/null || true
  fi
}
printf "EDITOR=%s\n" "${EDITOR:-}"
printf "PNPM_HOME=%s\n" "${PNPM_HOME:-}"
[ "${PNPM_HOME:-}" = "$HOME/Library/pnpm" ] || exit 1
printf "KUBECONFIG=%s\n" "${KUBECONFIG:-}"
printf "SSH_AUTH_SOCK=%s\n" "${SSH_AUTH_SOCK:-}"
printf "PATH=%s\n" "$PATH"
case ":$PATH:" in
  *":$HOME/Library/pnpm:"*) exit 1 ;;
esac
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) exit 1 ;;
esac
case ":$PATH:" in
  *":$HOME/.local/share/pnpm:"*) exit 1 ;;
esac
for cmd in node npm npx pnpm; do
  cmd_path=$(find_command_path "$cmd")
  if [ -z "$cmd_path" ]; then
    printf "%s=absent\n" "$cmd"
    exit 1
  fi
  printf "%s=%s\n" "$cmd" "$cmd_path"
  case "$cmd_path" in
    "$HOME"/.local/share/mise/shims/"$cmd") ;;
    *) exit 1 ;;
  esac
done
command -v maestro >/dev/null 2>&1 && printf "maestro=present\n" || printf "maestro=absent\n"
'

run_probe() {
  label=$1
  shift
  printf "\n## %s\n" "$label"
  "$@" "$probe"
}

run_probe "zsh -c" zsh -c
run_probe "zsh -lc" zsh -lc
run_probe "bash -c" bash -c
run_probe "bash -lc" bash -lc
run_probe "sh -c" sh -c

printf "\n## zshenv adapter\n"
zsh -c 'unset SSH_AUTH_SOCK; PATH=/usr/bin:/bin; . "$HOME/.zshenv"; printf "SSH_AUTH_SOCK=%s\n" "$SSH_AUTH_SOCK"'

printf "\n## profile entrypoint (sh)\n"
sh -c 'unset SSH_AUTH_SOCK; PATH=/usr/bin:/bin; . "$ENV_DIR/profile.sh"; printf "SSH_AUTH_SOCK=%s\n" "$SSH_AUTH_SOCK"'

printf "\n## launchd SSH_AUTH_SOCK override\n"
sh -c 'SSH_AUTH_SOCK=/var/run/com.apple.launchd.example/Listeners; PATH=/usr/bin:/bin; . "$ENV_DIR/profile.sh"; case "$SSH_AUTH_SOCK" in */rbw-*/ssh-agent-socket) printf "launchd-override=rbw\n" ;; *) printf "launchd-override=unexpected:%s\n" "$SSH_AUTH_SOCK"; exit 1 ;; esac'

printf "\n## machine host normalization\n"
sh -c 'unset KUBECONFIG ENV_NEXT_MACHINE HOSTNAME; HOST=Topaz.local; PATH=/usr/bin:/bin; . "$ENV_DIR/profile.sh"; printf "KUBECONFIG=%s\n" "${KUBECONFIG:-}"; case "${KUBECONFIG:-}" in "$HOME/.kube/hcloud:$HOME/.kube/legacy") ;; *) exit 1 ;; esac'

printf "\n## zshrc reloads stale env\n"
zsh -f -c 'unset KUBECONFIG ENV_NEXT_MACHINE HOSTNAME; HOST=Topaz.local; PATH=/usr/bin:/bin; ENV_NEXT_PROFILE_LOADED=1; ENV_NEXT_PROFILE_PATH=$PATH; unset ENV_NEXT_PROFILE_VERSION; source "$HOME/.zshrc"; printf "KUBECONFIG=%s\n" "${KUBECONFIG:-}"; case "${KUBECONFIG:-}" in "$HOME/.kube/hcloud:$HOME/.kube/legacy") ;; *) exit 1 ;; esac'

printf "\n## zshenv no lazy wrappers\n"
node_probe_dir=$(mktemp -d)
printf '%s\n' '22' > "$node_probe_dir/.nvmrc"
(
  cd "$node_probe_dir"
  ENV_DIR="$ENV_DIR" PATH=/usr/bin:/bin zsh -c '
    for cmd in node npm npx pnpm; do
      kind=$(whence -w "$cmd" 2>/dev/null || true)
      printf "%s\n" "$kind"
      case "$kind" in
        "$cmd: command") ;;
        *) exit 1 ;;
      esac
    done
    if whence -w corepack >/dev/null 2>&1; then
      printf "corepack=present\n"
      exit 1
    fi
    printf "corepack=absent\n"
  '
)

printf "\n## mise follows .nvmrc\n"
(
  cd "$node_probe_dir"
  requested=$(mise current node 2>/dev/null || true)
  printf "node=%s\n" "$requested"
  case "$requested" in 22*) ;; *) exit 1 ;; esac
)
