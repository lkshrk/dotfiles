#!/bin/sh
set -eu

ENV_DIR="${ENV_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
export ENV_DIR

tmpdir=
socket_pid=

fail() {
  printf 'fail: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  [ -z "${socket_pid:-}" ] || kill "$socket_pid" 2>/dev/null || true
  [ -z "${tmpdir:-}" ] || rm -rf "$tmpdir"
}
trap cleanup EXIT HUP INT TERM

tmpdir=$(mktemp -d)
home="$tmpdir/home"
runtime="$tmpdir/runtime"
node_bin="$home/.nvm/versions/node/v24.17.0/bin"

mkdir -p "$node_bin" "$home/.nvm/alias" "$home/.bun/bin" "$home/.local/bin" "$runtime/rbw"
printf '%s\n' '24' > "$home/.nvm/alias/default"

for cmd in node npm npx pnpm; do
  cat > "$node_bin/$cmd" <<EOF
#!/bin/sh
printf '%s\n' '$cmd from fake nvm'
EOF
  chmod +x "$node_bin/$cmd"
done

run_profile_probe() {
  label=$1
  expected_sock=$2

  printf '\n## %s\n' "$label"
  env -i \
    HOME="$home" \
    ENV_DIR="$ENV_DIR" \
    ENV_NEXT_OS=linux \
    XDG_RUNTIME_DIR="$runtime" \
    EXPECTED_SSH_AUTH_SOCK="$expected_sock" \
    SSH_AUTH_SOCK="$home/existing-agent.sock" \
    RBW_SSH_AUTH_SOCK="$home/missing-rbw-agent.sock" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    /bin/sh -c '
      set -eu

      fail() {
        printf "fail: %s\n" "$1" >&2
        exit 1
      }

      find_command_path() {
        command -v "$1" 2>/dev/null || true
      }

      . "$ENV_DIR/profile.sh"

      [ "${NVM_DIR:-}" = "$HOME/.nvm" ] || fail "NVM_DIR"
      [ "${BUN_INSTALL:-}" = "$HOME/.bun" ] || fail "BUN_INSTALL"
      [ "${GOPATH:-}" = "$HOME/go" ] || fail "GOPATH"
      [ "${GIT_CONFIG_GLOBAL:-}" = "$HOME/.config/git/config" ] || fail "GIT_CONFIG_GLOBAL"
      [ "${PNPM_HOME:-}" = "" ] || fail "PNPM_HOME still set"
      [ "${SSH_AUTH_SOCK:-}" = "$EXPECTED_SSH_AUTH_SOCK" ] || fail "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"

      case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) fail "missing HOME .local/bin" ;;
      esac

      case ":$PATH:" in
        *":/home/coder/.local/bin:"*) fail "hardcoded coder path present" ;;
      esac

      for cmd in node npm npx pnpm; do
        cmd_path=$(find_command_path "$cmd")
        expected="$NVM_DIR/versions/node/v24.17.0/bin/$cmd"
        [ "$cmd_path" = "$expected" ] || fail "$cmd path=$cmd_path"
        printf "%s=%s\n" "$cmd" "$cmd_path"
      done

      printf "SSH_AUTH_SOCK=%s\n" "${SSH_AUTH_SOCK:-}"
      printf "PATH=%s\n" "$PATH"
    '
}

run_profile_probe "linux without rbw socket" "$home/existing-agent.sock"

socket_path="$runtime/rbw/ssh-agent-socket"
python3 - "$socket_path" <<'PY' &
import os
import signal
import socket
import sys
import time

path = sys.argv[1]
try:
    os.unlink(path)
except FileNotFoundError:
    pass

server = socket.socket(socket.AF_UNIX)
server.bind(path)
server.listen(1)

def stop(_signum, _frame):
    server.close()
    raise SystemExit(0)

signal.signal(signal.SIGTERM, stop)

while True:
    time.sleep(1)
PY
socket_pid=$!

i=0
while [ "$i" -lt 50 ] && [ ! -S "$socket_path" ]; do
  sleep 0.1
  i=$((i + 1))
done
[ -S "$socket_path" ] || fail "rbw socket fixture did not start"

run_profile_probe "linux with existing rbw socket" "$socket_path"
