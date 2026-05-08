# Lazy secret loaders backed by Bitwarden via rbw — fetched on first access,
# cached in the current shell. with-secrets fetches uncached items in parallel.
(( $+commands[rbw] )) || return 0
rbw config show &>/dev/null || { print -u2 "rbw: not configured — run: rbw config set email <you@example.com>"; return 0; }

_rbw_get_or_unlock() {
  local item=$1 val
  val=$(rbw get "$item" 2>/dev/null) && { print -n "$val"; return 0; }

  if [[ -t 0 && -t 1 ]]; then
    print -u2 "rbw: vault locked; unlocking for '$item'"
    rbw unlock </dev/tty >/dev/tty 2>/dev/tty && val=$(rbw get "$item" 2>/dev/null)
  fi

  [[ -n $val ]] || return 1
  print -n "$val"
}

_lazy_secret() {
  local var=$1 item=$2
  if [[ -z ${(P)var} ]]; then
    local val
    val=$(_rbw_get_or_unlock "$item") || {
      print -u2 "rbw: could not retrieve '$item' for $var; vault may be locked, item may be missing, or rbw auth may need attention"
      return 1
    }
    typeset -gx "$var=$val"
  fi
}

openai_key()   { _lazy_secret OPENAI_API_KEY    openai-api-key; }
zai_key()      { _lazy_secret ZAI_API_KEY       zai-api-key; }
hf_key()       { _lazy_secret HF_TOKEN          hf-token; }
context7_key() { _lazy_secret CONTEXT7_API_KEY  context7-api-key; }
pocket_id_key()   { _lazy_secret POCKET_ID_API_KEY    pocket-id-api-key; }
h_cloud_age_key() { _lazy_secret SOPS_AGE_KEY    h-cloud-age-key; }

# Run a command with secrets injected as env vars, fetched on demand.
# Skips items already in env, fetches the rest in parallel (~350ms total
# instead of ~350ms × N sequential).
# Secret fetches are best-effort: failures warn and the command still runs.
# Usage: with-secrets <item> <ENV_VAR> [<item> <ENV_VAR> ...] -- <cmd> [args...]
with-secrets() {
  setopt local_options no_bg_nice

  local -a pairs missing_items missing_vars
  while [[ $# -gt 0 && $1 != "--" ]]; do
    pairs+=("$1" "$2"); shift 2
  done
  [[ $1 == "--" ]] || { print -u2 "with-secrets: missing '--' before command"; return 2; }
  shift

  # Pass 1: skip anything already in env
  local i item var
  for (( i = 1; i <= ${#pairs}; i += 2 )); do
    item=${pairs[i]}; var=${pairs[i+1]}
    [[ -n ${(P)var} ]] && continue
    missing_items+=("$item"); missing_vars+=("$var")
  done

  # Pass 2: parallel fetch uncached items
  if (( ${#missing_items} )); then
    # Pre-flight: ensure vault is unlocked once, before spawning parallel jobs.
    # Without this, N background subshells each try `rbw unlock` simultaneously,
    # causing an endless password-prompt loop.
    if ! rbw get "${missing_items[1]}" &>/dev/null; then
      if [[ -t 0 && -t 1 ]]; then
        print -u2 "rbw: vault locked; unlocking…"
        rbw unlock </dev/tty >/dev/tty 2>/dev/tty || {
          print -u2 "rbw: unlock failed; continuing without secrets"
          "$@"
          return
        }
      fi
    fi

    local -a pids tmpfiles
    local val
    for (( i = 1; i <= ${#missing_items}; i++ )); do
      tmpfiles+=("$(mktemp)")
      ( rbw get "${missing_items[i]}" > "${tmpfiles[i]}" 2>/dev/null ) &
      pids+=($!)
    done
    for (( i = 1; i <= ${#pids}; i++ )); do
      wait ${pids[i]} || true
      val=$(<"${tmpfiles[i]}")
      rm -f "${tmpfiles[i]}"
      if [[ -z $val ]]; then
        print -u2 "rbw: could not retrieve '${missing_items[i]}' for ${missing_vars[i]}; continuing without it"
        continue
      fi
      export "${missing_vars[i]}=$val"
    done
  fi

  "$@"
}
