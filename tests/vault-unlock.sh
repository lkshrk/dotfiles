#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
unlock="$("$repo/scripts/render-home.sh" towerr "$tmp/render")/.config/env/bin/vault-unlock"
export XDG_RUNTIME_DIR="$tmp/run" FAKE_VAULT="$tmp/state" DISPLAY=:0
mkdir -p "$tmp/bin" "$XDG_RUNTIME_DIR" "$FAKE_VAULT"
dir="$XDG_RUNTIME_DIR/vault"

cat > "$tmp/bin/bw" <<'EOF'
#!/bin/sh
case $1 in
  unlock)
    echo x >> "$FAKE_VAULT/prompts"
    [ "${FAKE_VAULT_UNLOCK:-ok}" = ok ] || exit 1
    printf 'fake-session-key'
    sleep 30 ;;
  sync) [ "$BW_SESSION" = fake-session-key ] && [ "$BITWARDEN_DESKTOP_PROXY_PATH" != "" ] && : > "$FAKE_VAULT/synced" ;;
  lock) : > "$FAKE_VAULT/locked" ;;
  *) exit 1 ;;
esac
EOF
cat > "$tmp/bin/rbw" <<'EOF'
#!/bin/sh
case $1 in
  unlocked) [ -e "$FAKE_VAULT/unlocked" ] ;;
  unlock)
    echo x >> "$FAKE_VAULT/prompts"
    [ "${FAKE_VAULT_UNLOCK:-ok}" = ok ] && : > "$FAKE_VAULT/unlocked" ;;
  lock) rm -f "$FAKE_VAULT/unlocked" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/bw" "$tmp/bin/rbw"
export PATH="$tmp/bin:$PATH"

fail() { printf 'vault-unlock: %s\n' "$1" >&2; exit 1; }
reset() { rm -rf "${FAKE_VAULT:?}"/* "$dir"; }
prompts() { [ -e "$FAKE_VAULT/prompts" ] && wc -l < "$FAKE_VAULT/prompts" | tr -d ' ' || echo 0; }
in_tty() { python3 -c 'import os, pty, sys; sys.exit(os.waitstatus_to_exitcode(pty.spawn(sys.argv[1:])))' "$@"; }

for backend in bw rbw; do
  export VAULT_BACKEND=$backend

  reset
  "$unlock" --check && fail "$backend: --check passed while locked"
  [ "$(prompts)" = 0 ] || fail "$backend: --check prompted"

  reset
  start=$SECONDS
  "$unlock" </dev/null || fail "$backend: non-terminal unlock in a graphical session failed"
  (( SECONDS - start < 10 )) || fail "$backend: unlock waited for bw to exit"
  "$unlock" --check || fail "$backend: --check failed after unlocking"
  "$unlock" </dev/null || fail "$backend: second unlock failed"
  [ "$(prompts)" = 1 ] || fail "$backend: an unlocked vault prompted again"

  reset; mkdir -p "$dir"; : > "$dir/unlock.cancelled"
  out=$("$unlock" </dev/null 2>&1) && fail "$backend: non-terminal caller ignored the cancel hold-off"
  [ -z "$out" ] || fail "$backend: non-terminal hold-off was not silent: $out"
  [ "$(prompts)" = 0 ] || fail "$backend: non-terminal caller prompted during the hold-off"
  in_tty "$unlock" >/dev/null || fail "$backend: terminal caller did not unlock past the cancel marker"
  [ ! -e "$dir/unlock.cancelled" ] || fail "$backend: successful unlock kept the cancel marker"

  reset
  out=$(FAKE_VAULT_UNLOCK=cancel in_tty "$unlock") && fail "$backend: cancelled unlock succeeded"
  case $out in *'vault: unlock failed'*) ;; *) fail "$backend: cancelled terminal unlock gave no reason: $out" ;; esac
  [ -e "$dir/unlock.cancelled" ] || fail "$backend: cancelled unlock left no marker"

  reset
  rc=0
  out=$(DISPLAY='' WAYLAND_DISPLAY='' "$unlock" </dev/null 2>&1) || rc=$?
  [ "$rc" = 2 ] || fail "$backend: no terminal and no display did not exit 2 (got $rc)"

  if command -v flock >/dev/null 2>&1; then
    reset; mkdir -p "$dir"
    exec 8>"$dir/unlock.lock"
    flock 8
    (
      sleep 1
      if [ "$backend" = bw ]; then printf 'fake-session-key' > "$dir/bw-session"; else : > "$FAKE_VAULT/unlocked"; fi
      flock -u 8
    ) &
    out=$(in_tty "$unlock" 8>&-) || fail "$backend: terminal waiter failed: $out"
    wait
    exec 8>&-
    case $out in *'vault: waiting for another unlock prompt'*) ;; *) fail "$backend: terminal waiter was silent: $out" ;; esac
    [ "$(prompts)" = 0 ] || fail "$backend: waiter prompted although the other caller unlocked"
  fi
done

export VAULT_BACKEND=bw
reset
key=$("$unlock" --session </dev/null) || fail 'bw: --session failed'
[ "$key" = fake-session-key ] || fail "bw: --session printed '$key'"
[ "$(stat -c %a "$dir/bw-session")" = 600 ] || fail 'bw: session file is not 0600'
[ "$(stat -c %a "$dir")" = 700 ] || fail 'bw: session directory is not 0700'
for _ in $(seq 50); do [ -e "$FAKE_VAULT/synced" ] && break; sleep 0.1; done
[ -e "$FAKE_VAULT/synced" ] || fail 'bw: unlock did not sync with the new session'
"$unlock" --lock
[ ! -e "$dir/bw-session" ] || fail 'bw: --lock kept the session file'
[ -e "$FAKE_VAULT/locked" ] || fail 'bw: --lock did not lock bw'

printf '%s\n' 'vault-unlock: bw and rbw backends, cancel hold-off, waiting, session file and lock passed'
