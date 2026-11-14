#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

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
ENV_DIR="${ENV_DIR:-$("$repo/scripts/render-home.sh" towerr "$tmpdir/render")/.config/env}"
export ENV_DIR
home="$tmpdir/home"
runtime="$tmpdir/runtime"
node_bin="$home/.local/share/mise/shims"

mkdir -p "$node_bin" "$home/.local/bin" "$runtime/rbw"

for cmd in node npm npx pnpm; do
  cat > "$node_bin/$cmd" <<EOF
#!/bin/sh
printf '%s\n' '$cmd from fake mise shim'
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
    ENV_OS=linux \
    XDG_RUNTIME_DIR="$runtime" \
    TMPDIR="$tmpdir" \
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

      [ "${GOPATH:-}" = "$HOME/go" ] || fail "GOPATH"
      [ "${PNPM_HOME:-}" = "$HOME/.local/share/pnpm" ] || fail "PNPM_HOME=$PNPM_HOME"
      [ "${SSH_AUTH_SOCK:-}" = "$EXPECTED_SSH_AUTH_SOCK" ] || fail "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"

      case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) fail "missing HOME .local/bin" ;;
      esac

      case ":$PATH:" in
        *":$HOME/.local/bin:$HOME/.local/share/mise/shims:"*) ;;
        *) fail "mise shims must follow HOME .local/bin" ;;
      esac
      case ":$PATH:" in
        *":$HOME/.local/share/mise/shims:"*":/usr/bin:"*) ;;
        *) fail "mise shims must precede /usr/bin" ;;
      esac

      case ":$PATH:" in
        *":$PNPM_HOME/bin:"*) ;;
        *) fail "missing PNPM_HOME bin" ;;
      esac

      for cmd in node npm npx pnpm; do
        cmd_path=$(find_command_path "$cmd")
        expected="$HOME/.local/share/mise/shims/$cmd"
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


printf '\n## pre-rename guard\n'
env -i HOME="$home" ENV_DIR="$ENV_DIR" PATH=/usr/bin:/bin /bin/sh -c '
  . "$ENV_DIR/profile.sh"
  probe=". \"\$ENV_DIR/profile.sh\"; printf \"%s %s\n\" \"\${ENV_PROFILE_LOADED:-unset}\" \"\${ENV_NEXT_PROFILE_LOADED:-unset}\""
  fresh=$(env -u ENV_PROFILE_LOADED -u ENV_PROFILE_PATH -u ENV_PROFILE_VERSION ENV_NEXT_PROFILE_LOADED=1 \
    ENV_NEXT_PROFILE_PATH="$PATH" ENV_NEXT_PROFILE_VERSION="$ENV_PROFILE_VERSION" /bin/sh -c "$probe")
  stale=$(env -u ENV_PROFILE_LOADED -u ENV_PROFILE_PATH -u ENV_PROFILE_VERSION ENV_NEXT_PROFILE_LOADED=1 \
    ENV_NEXT_PROFILE_PATH="$PATH" ENV_NEXT_PROFILE_VERSION=0 /bin/sh -c "$probe")
  printf "fresh=%s stale=%s\n" "$fresh" "$stale"
  [ "$fresh" = "unset 1" ] && [ "$stale" = "1 unset" ]
' || fail "pre-rename profile guard"
