# Lazy secret loaders backed by Bitwarden via rbw.
# Secrets live in the `ENV` folder of the vault. No values are ever exported
# eagerly — they are fetched on first access and cached in the current shell.

# Guard: if rbw isn't installed, skip silently.
(( $+commands[rbw] )) || return 0

# Internal: fetch a vault item once, cache into a shell variable, echo it.
# $1 = env var name to cache into
# $2 = bitwarden item name
_lazy_secret() {
  local var=$1 item=$2
  if [[ -z ${(P)var} ]]; then
    local val
    val=$(rbw get "$item" 2>/dev/null) || {
      print -u2 "rbw: failed to fetch '$item' (run: rbw unlock)"
      return 1
    }
    typeset -gx "$var=$val"
  fi
  print -r -- "${(P)var}"
}

# Convenience getters — print the value so they compose with $(...) if needed.
openai_key()   { _lazy_secret OPENAI_API_KEY    openai-api-key; }
zai_key()      { _lazy_secret ZAI_API_KEY       zai-api-key; }
hf_key()       { _lazy_secret HF_TOKEN          hf-token; }
context7_key() { _lazy_secret CONTEXT7_API_KEY  context7-api-key; }

# Run a command with secrets injected as env vars, fetched on demand.
# Usage: with-secrets <item> <ENV_VAR> [<item> <ENV_VAR> ...] -- <cmd> [args...]
with-secrets() {
  local -a pairs
  while [[ $# -gt 0 && $1 != "--" ]]; do
    pairs+=("$1" "$2"); shift 2
  done
  [[ $1 == "--" ]] || { print -u2 "with-secrets: missing '--' before command"; return 2; }
  shift

  local i item var val
  for (( i = 1; i <= ${#pairs}; i += 2 )); do
    item=${pairs[i]}
    var=${pairs[i+1]}
    val=$(rbw get "$item" 2>/dev/null) || {
      print -u2 "rbw: failed to fetch '$item' (run: rbw unlock)"
      return 1
    }
    export "$var=$val"
  done

  "$@"
}

# Wrap `claude` so it runs with all four keys injected at exec time.
# Plain `command claude` still works for cases where you want no secrets.
claude() {
  with-secrets \
    openai-api-key    OPENAI_API_KEY \
    zai-api-key       ZAI_API_KEY \
    hf-token          HF_TOKEN \
    context7-api-key  CONTEXT7_API_KEY \
    -- command claude "$@"
}
