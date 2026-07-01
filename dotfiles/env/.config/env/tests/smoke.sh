#!/bin/sh
set -eu

ENV_DIR="${ENV_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
export ENV_DIR

tmpdir=
nvm_probe_dir=
nvm_default_probe_dir=
cleanup() {
  [ -z "${tmpdir:-}" ] || rm -rf "$tmpdir"
  [ -z "${nvm_probe_dir:-}" ] || rm -rf "$nvm_probe_dir"
  [ -z "${nvm_default_probe_dir:-}" ] || rm -rf "$nvm_default_probe_dir"
}
trap cleanup EXIT HUP INT TERM

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
printf "GIT_CONFIG_GLOBAL=%s\n" "${GIT_CONFIG_GLOBAL:-}"
printf "NVM_DIR=%s\n" "${NVM_DIR:-}"
printf "PNPM_HOME=%s\n" "${PNPM_HOME:-}"
[ -z "${PNPM_HOME:-}" ] || exit 1
printf "KUBECONFIG=%s\n" "${KUBECONFIG:-}"
printf "SSH_AUTH_SOCK=%s\n" "${SSH_AUTH_SOCK:-}"
printf "PATH=%s\n" "$PATH"
case ":$PATH:" in
  *":$HOME/Library/pnpm:"*) exit 1 ;;
esac
case ":$PATH:" in
  *":$HOME/Library/pnpm/bin:"*) exit 1 ;;
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
    "$NVM_DIR"/versions/node/*/bin/"$cmd") ;;
    *) exit 1 ;;
  esac
done
command -v bun >/dev/null 2>&1 && printf "bun=present\n" || printf "bun=absent\n"
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
zsh -c 'unset SSH_AUTH_SOCK; PATH=/usr/bin:/bin; . "$HOME/.zshenv"; printf "GIT_CONFIG_GLOBAL=%s\n" "$GIT_CONFIG_GLOBAL"; printf "SSH_AUTH_SOCK=%s\n" "$SSH_AUTH_SOCK"'

printf "\n## profile entrypoint (sh)\n"
sh -c 'unset SSH_AUTH_SOCK; PATH=/usr/bin:/bin; . "$ENV_DIR/profile.sh"; printf "GIT_CONFIG_GLOBAL=%s\n" "$GIT_CONFIG_GLOBAL"; printf "SSH_AUTH_SOCK=%s\n" "$SSH_AUTH_SOCK"'

printf "\n## launchd SSH_AUTH_SOCK override\n"
sh -c 'SSH_AUTH_SOCK=/var/run/com.apple.launchd.example/Listeners; PATH=/usr/bin:/bin; . "$ENV_DIR/profile.sh"; case "$SSH_AUTH_SOCK" in */rbw-*/ssh-agent-socket) printf "launchd-override=rbw\n" ;; *) printf "launchd-override=unexpected:%s\n" "$SSH_AUTH_SOCK"; exit 1 ;; esac'

printf "\n## machine host normalization\n"
sh -c 'unset KUBECONFIG ENV_NEXT_MACHINE HOSTNAME; HOST=Topaz.local; PATH=/usr/bin:/bin; . "$ENV_DIR/profile.sh"; printf "KUBECONFIG=%s\n" "${KUBECONFIG:-}"; case "${KUBECONFIG:-}" in "$HOME/.kube/hcloud:$HOME/.kube/legacy") ;; *) exit 1 ;; esac'

printf "\n## zshrc reloads stale env\n"
zsh -f -c 'unset KUBECONFIG ENV_NEXT_MACHINE HOSTNAME; HOST=Topaz.local; PATH=/usr/bin:/bin; ENV_NEXT_PROFILE_LOADED=1; ENV_NEXT_PROFILE_PATH=$PATH; unset ENV_NEXT_PROFILE_VERSION; source "$HOME/.zshrc"; printf "KUBECONFIG=%s\n" "${KUBECONFIG:-}"; case "${KUBECONFIG:-}" in "$HOME/.kube/hcloud:$HOME/.kube/legacy") ;; *) exit 1 ;; esac'

printf "\n## zshenv no lazy wrappers\n"
nvm_probe_dir=$(mktemp -d)
printf '%s\n' 'lts/*' > "$nvm_probe_dir/.nvmrc"
(
  cd "$nvm_probe_dir"
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

printf "\n## zshenv nvm default path\n"
nvm_default_probe_dir=$(mktemp -d)
(
  cd "$nvm_default_probe_dir"
  ENV_DIR="$ENV_DIR" PATH=/usr/bin:/bin zsh -c '
    node --version
    for cmd in node npm npx pnpm; do
      cmd_path=$(whence -p "$cmd")
      printf "%s_path=%s\n" "$cmd" "$cmd_path"
      case "$cmd_path" in
        "$NVM_DIR"/versions/node/*/bin/"$cmd") ;;
        *) exit 1 ;;
      esac
    done
  '
)

printf "\n## interactive zsh nvmrc auto-use\n"
(
  cd "$nvm_probe_dir"
  ENV_DIR="$ENV_DIR" PATH=/usr/bin:/bin zsh -ic '
    node --version
    printf "NVM_BIN=%s\n" "${NVM_BIN:-}"
    case "${NVM_BIN:-}" in
      "$NVM_DIR"/versions/node/*/bin) ;;
      *) exit 1 ;;
    esac
    for cmd in node npm npx pnpm; do
      cmd_path=$(whence -p "$cmd")
      printf "%s_path=%s\n" "$cmd" "$cmd_path"
      case "$cmd_path" in
        "$NVM_BIN"/"$cmd") ;;
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

printf "\n## rbw-env profile wrapper\n"
tmpdir=$(mktemp -d)
cat > "$tmpdir/rbw" <<'EOF'
#!/bin/sh
case "$1" in
  unlocked) exit 0 ;;
  get) printf 'secret:%s\n' "$2" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmpdir/rbw"
env -i HOME="$HOME" ENV_DIR="$ENV_DIR" PATH="$tmpdir:/usr/bin:/bin" "$ENV_DIR/bin/rbw-env" \
  claude \
  -- sh -c 'printf "HF_TOKEN=%s\n" "$HF_TOKEN"'

printf "\n## rbw-env locked non-interactive\n"
cat > "$tmpdir/rbw" <<'EOF'
#!/bin/sh
case "$1" in
  unlocked) exit 1 ;;
  unlock) exit 1 ;;
  get) exit 1 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmpdir/rbw"
if env -i HOME="$HOME" ENV_DIR="$ENV_DIR" PATH="$tmpdir:/usr/bin:/bin" "$ENV_DIR/bin/rbw-env" claude -- sh -c 'printf "unexpected-run\n"' >/dev/null 2>&1; then
  printf '%s\n' 'locked=unexpected-run'
  exit 1
else
  printf '%s\n' 'locked=refused'
fi

printf "\n## rbw-env missing rbw strict\n"
empty_path="$tmpdir/empty"
mkdir -p "$empty_path"
if env -i HOME="$HOME" ENV_DIR="$ENV_DIR" PATH="$empty_path" "$ENV_DIR/bin/rbw-env" claude -- sh -c 'printf "unexpected-run\n"' >/dev/null 2>&1; then
  printf '%s\n' 'missing-rbw=unexpected-run'
  exit 1
else
  printf '%s\n' 'missing-rbw=refused'
fi

printf "\n## rbw-env missing rbw best effort\n"
RBW_ENV_STRICT=0 PATH="$empty_path" "$ENV_DIR/bin/rbw-env" claude -- /bin/sh -c 'printf "missing-rbw-best-effort=ran\n"'
