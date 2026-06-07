#!/bin/sh
set -eu

ENV_DIR="${ENV_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
export ENV_DIR

probe='
unset SSH_AUTH_SOCK
PATH=/usr/bin:/bin
. "$ENV_DIR/profile.sh"
printf "EDITOR=%s\n" "${EDITOR:-}"
printf "GIT_CONFIG_GLOBAL=%s\n" "${GIT_CONFIG_GLOBAL:-}"
printf "NVM_DIR=%s\n" "${NVM_DIR:-}"
printf "KUBECONFIG=%s\n" "${KUBECONFIG:-}"
printf "SSH_AUTH_SOCK=%s\n" "${SSH_AUTH_SOCK:-}"
printf "PATH=%s\n" "$PATH"
command -v npm >/dev/null 2>&1 && printf "npm=present\n" || printf "npm=absent\n"
command -v pnpm >/dev/null 2>&1 && printf "pnpm=present\n" || printf "pnpm=absent\n"
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
zsh -c 'unset SSH_AUTH_SOCK; PATH=/usr/bin:/bin; . "$ENV_DIR/consumers/zshenv.zsh"; printf "GIT_CONFIG_GLOBAL=%s\n" "$GIT_CONFIG_GLOBAL"; printf "SSH_AUTH_SOCK=%s\n" "$SSH_AUTH_SOCK"'

printf "\n## profile adapter\n"
sh -c 'unset SSH_AUTH_SOCK; PATH=/usr/bin:/bin; . "$ENV_DIR/consumers/profile.sh"; printf "GIT_CONFIG_GLOBAL=%s\n" "$GIT_CONFIG_GLOBAL"; printf "SSH_AUTH_SOCK=%s\n" "$SSH_AUTH_SOCK"'

printf "\n## zprofile adapter\n"
zsh -c 'unset SSH_AUTH_SOCK; PATH=/usr/bin:/bin; . "$ENV_DIR/consumers/zprofile.zsh"; printf "GIT_CONFIG_GLOBAL=%s\n" "$GIT_CONFIG_GLOBAL"; printf "SSH_AUTH_SOCK=%s\n" "$SSH_AUTH_SOCK"'

printf "\n## rbw-env profile wrapper\n"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
cat > "$tmpdir/rbw" <<'EOF'
#!/bin/sh
case "$1" in
  unlocked) exit 0 ;;
  get) printf 'secret:%s\n' "$2" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmpdir/rbw"
PATH="$tmpdir:/usr/bin:/bin" "$ENV_DIR/bin/rbw-env" \
  claude \
  -- sh -c 'printf "OPENAI_API_KEY=%s\n" "$OPENAI_API_KEY"'

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
if PATH="$tmpdir:/usr/bin:/bin" "$ENV_DIR/bin/rbw-env" claude -- sh -c 'printf "unexpected-run\n"' >/dev/null 2>&1; then
  printf '%s\n' 'locked=unexpected-run'
  exit 1
else
  printf '%s\n' 'locked=refused'
fi

printf "\n## rbw-env missing rbw strict\n"
empty_path="$tmpdir/empty"
mkdir -p "$empty_path"
if PATH="$empty_path" "$ENV_DIR/bin/rbw-env" claude -- sh -c 'printf "unexpected-run\n"' >/dev/null 2>&1; then
  printf '%s\n' 'missing-rbw=unexpected-run'
  exit 1
else
  printf '%s\n' 'missing-rbw=refused'
fi

printf "\n## rbw-env missing rbw best effort\n"
RBW_ENV_STRICT=0 PATH="$empty_path" "$ENV_DIR/bin/rbw-env" claude -- /bin/sh -c 'printf "missing-rbw-best-effort=ran\n"'
