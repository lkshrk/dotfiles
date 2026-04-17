# Lazy secret loaders backed by Bitwarden via rbw — fetched on first access,
# cached in the current shell.
(( $+commands[rbw] )) || return 0

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

claude() {
  with-secrets \
    openai-api-key    OPENAI_API_KEY \
    zai-api-key       ZAI_API_KEY \
    hf-token          HF_TOKEN \
    context7-api-key  CONTEXT7_API_KEY \
    -- command claude "$@"
}
