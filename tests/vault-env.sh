#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
home="$("$repo/scripts/render-home.sh" towerr "$tmp/render")"
export ENV_DIR="$home/.config/env" XDG_RUNTIME_DIR="$tmp/run" FAKE_VAULT="$tmp/state" DISPLAY=:0 VAULT_BACKEND=bw
mkdir -p "$tmp/bin" "$XDG_RUNTIME_DIR" "$FAKE_VAULT" "$ENV_DIR/secrets"
env_cmd="$ENV_DIR/bin/vault-env"
get_cmd="$ENV_DIR/bin/vault-get"

cat > "$FAKE_VAULT/items.json" <<'EOF'
[
  {"name": "local-agents", "folderId": "f1", "login": {"username": null, "password": "gw-key"}, "notes": null},
  {"name": "local-agents", "folderId": null, "login": {"username": null, "password": "wrong-folder"}, "notes": null},
  {"name": "gh-cli", "folderId": null, "login": {"username": "me", "password": "gh-token"}, "notes": null},
  {"name": "root-CA", "folderId": null, "login": {"username": "CERTDATA", "password": null}, "notes": null},
  {"name": "note-only", "folderId": null, "login": null, "notes": "note-secret"},
  {"name": "dup", "folderId": null, "login": {"password": "a"}, "notes": null},
  {"name": "dup", "folderId": null, "login": {"password": "b"}, "notes": null}
]
EOF
printf '%s\n' '[{"id": "f1", "name": "ENV"}, {"id": null, "name": "No Folder"}]' > "$FAKE_VAULT/folders.json"

cat > "$tmp/bin/bw" <<'EOF'
#!/bin/sh
case $1 in
  unlock)
    echo x >> "$FAKE_VAULT/prompts"
    printf '%s' "$(cat "$FAKE_VAULT/next-key" 2>/dev/null || echo good-key)"
    rm -f "$FAKE_VAULT/next-key"
    sleep 30 ;;
  list)
    [ "${BW_SESSION:-}" = good-key ] && [ -n "${BITWARDEN_DESKTOP_PROXY_PATH:-}" ] || exit 1
    echo x >> "$FAKE_VAULT/lists"
    cat "$FAKE_VAULT/$2.json" ;;
  sync) : > "$FAKE_VAULT/synced" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/bw"
export PATH="$tmp/bin:$PATH"

unset LITELLM_API LITELLM_API_KEY GITHUB_TOKEN NOTE A B MISSING DUP BW_SESSION
fail() { printf 'vault-env: %s\n' "$1" >&2; exit 1; }
count() { [ -e "$FAKE_VAULT/$1" ] && wc -l < "$FAKE_VAULT/$1" | tr -d ' ' || echo 0; }
reset() { rm -rf "$XDG_RUNTIME_DIR/vault" "$FAKE_VAULT/prompts" "$FAKE_VAULT/lists" "$FAKE_VAULT/next-key" "$FAKE_VAULT/synced"; }

printf '%s\n' '# comment' 'ENV/local-agents LITELLM_API' 'gh-cli GITHUB_TOKEN' 'note-only NOTE' > "$ENV_DIR/secrets/test.envmap"
printf '%s\n' 'missing-item MISSING' 'gh-cli GITHUB_TOKEN' > "$ENV_DIR/secrets/missing.envmap"
printf '%s\n' 'dup DUP' > "$ENV_DIR/secrets/dup.envmap"

reset
out=$("$env_cmd" test -- sh -c 'printf "%s|%s|%s|%s" "$LITELLM_API" "$GITHUB_TOKEN" "$NOTE" "${BW_SESSION:-unset}"' </dev/null 2>/dev/null) ||
  fail 'profile run failed'
[ "$out" = 'gw-key|gh-token|note-secret|unset' ] || fail "profile injected '$out'"
[ "$(count lists)" = 2 ] || fail "one run listed $(count lists) times instead of items and folders once"
[ "$(count prompts)" = 1 ] || fail 'profile run did not unlock exactly once'

out=$(GITHUB_TOKEN=keep "$env_cmd" test -- sh -c 'printf %s "$GITHUB_TOKEN"' </dev/null 2>/dev/null)
[ "$out" = keep ] || fail 'an already-set variable was overwritten'
[ "$(count prompts)" = 1 ] || fail 'an unlocked vault prompted again'

out=$("$env_cmd" missing -- true </dev/null 2>&1) && fail 'strict mode ran with a missing secret'
case $out in *'could not retrieve missing-item for MISSING'*) ;; *) fail "missing secret gave no reason: $out" ;; esac
out=$(VAULT_ENV_STRICT=0 "$env_cmd" missing -- sh -c 'printf %s "$GITHUB_TOKEN"' </dev/null 2>/dev/null) ||
  fail 'non-strict mode refused to run'
[ "$out" = gh-token ] || fail 'non-strict mode lost the secrets it found'

"$env_cmd" dup -- true </dev/null 2>/dev/null && fail 'an ambiguous item name was accepted'

out=$("$env_cmd" --pairs gh-cli A ENV/local-agents B -- sh -c 'printf "%s|%s" "$A" "$B"' </dev/null 2>/dev/null)
[ "$out" = 'gh-token|gw-key' ] || fail "--pairs injected '$out'"

reset; printf 'stale-key' > "$FAKE_VAULT/next-key"
out=$("$env_cmd" --pairs gh-cli A -- sh -c 'printf %s "$A"' </dev/null 2>/dev/null) || fail 'a rejected session was not replaced'
[ "$out" = gh-token ] || fail 'retry after a rejected session injected the wrong value'
[ "$(count prompts)" = 2 ] || fail 'a rejected session did not unlock again exactly once'

reset
[ "$("$get_cmd" gh-cli </dev/null)" = gh-token ] || fail 'vault-get password'
[ "$("$get_cmd" --field username root-CA </dev/null)" = CERTDATA ] || fail 'vault-get --field username'
[ "$("$get_cmd" ENV/local-agents </dev/null)" = gw-key ] || fail 'vault-get folder/item'
"$get_cmd" dup </dev/null >/dev/null && fail 'vault-get accepted an ambiguous name'
"$get_cmd" --field bogus gh-cli </dev/null 2>/dev/null && fail 'vault-get accepted an unknown field'
for _ in $(seq 50); do [ -e "$FAKE_VAULT/synced" ] && break; sleep 0.1; done
[ -e "$FAKE_VAULT/synced" ] || fail 'unlock did not sync'

printf '%s\n' 'vault-env: profiles, --pairs, strict mode, ambiguity, session retry and vault-get passed'
