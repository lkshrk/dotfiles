#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
once="$("$repo/scripts/render-home.sh" towerr "$tmp/render")/.config/env/bin/rbw-unlock-once"
export XDG_RUNTIME_DIR="$tmp/run" FAKE_RBW="$tmp/state" DISPLAY=:0
mkdir -p "$tmp/bin" "$XDG_RUNTIME_DIR" "$FAKE_RBW"
cancelled="$XDG_RUNTIME_DIR/rbw-unlock.cancelled"

cat > "$tmp/bin/rbw" <<'EOF'
#!/bin/sh
case $1 in
  unlocked) [ -e "$FAKE_RBW/unlocked" ] ;;
  unlock)
    echo x >> "$FAKE_RBW/prompts"
    [ "${FAKE_RBW_UNLOCK:-ok}" = ok ] && : > "$FAKE_RBW/unlocked" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/rbw"
export PATH="$tmp/bin:$PATH"

fail() { printf 'rbw-unlock-once: %s\n' "$1" >&2; exit 1; }
reset() { rm -f "$FAKE_RBW"/* "$cancelled"; }
prompts() { [ -e "$FAKE_RBW/prompts" ] && wc -l < "$FAKE_RBW/prompts" | tr -d ' ' || echo 0; }
in_tty() { python3 -c 'import os, pty, sys; sys.exit(os.waitstatus_to_exitcode(pty.spawn(sys.argv[1:])))' "$@"; }

reset; : > "$cancelled"
out=$("$once" </dev/null 2>&1) && fail 'non-terminal caller ignored the cancel hold-off'
[ -z "$out" ] || fail "non-terminal hold-off was not silent: $out"
[ "$(prompts)" = 0 ] || fail 'non-terminal caller prompted during the hold-off'

reset; : > "$cancelled"
in_tty "$once" >/dev/null || fail 'terminal caller did not unlock past the cancel marker'
[ "$(prompts)" = 1 ] || fail 'terminal caller did not prompt'
[ ! -e "$cancelled" ] || fail 'successful unlock kept the cancel marker'

reset
out=$(FAKE_RBW_UNLOCK=cancel in_tty "$once") && fail 'cancelled unlock succeeded'
case $out in *'rbw: unlock failed'*) ;; *) fail "cancelled terminal unlock gave no reason: $out" ;; esac
[ -e "$cancelled" ] || fail 'cancelled unlock left no marker'
out=$(FAKE_RBW_UNLOCK=cancel "$once" </dev/null 2>&1) && fail 'non-terminal unlock succeeded'
[ -z "$out" ] || fail "non-terminal failure was not silent: $out"

if command -v flock >/dev/null 2>&1; then
  reset
  exec 8>"$XDG_RUNTIME_DIR/rbw-unlock.lock"
  flock 8
  (sleep 1; : > "$FAKE_RBW/unlocked"; flock -u 8) &
  out=$(in_tty "$once" 8>&-) || fail "terminal waiter failed: $out"
  wait
  exec 8>&-
  case $out in *'rbw: waiting for another unlock prompt'*) ;; *) fail "terminal waiter was silent: $out" ;; esac
  [ "$(prompts)" = 0 ] || fail 'waiter prompted although the other caller unlocked'
fi

printf '%s\n' 'rbw-unlock-once: cancel hold-off, terminal bypass and waiting message passed'
