# Lazy secret loaders backed by Bitwarden via rbw — fetched on first access,
# cached in the current shell. with-secrets fetches uncached items in parallel.
(( $+commands[rbw] )) || return 0
rbw config show &>/dev/null || { print -u2 "rbw: not configured — run: rbw config set email <you@example.com>"; return 0; }

_rbw_get_or_unlock() {
  local item=$1 val
  val=$(rbw get "$item" 2>/dev/null) || {
    rbw unlock 2>/dev/null && val=$(rbw get "$item" 2>/dev/null)
  }
  [[ -n $val ]] || return 1
  print -n "$val"
}

_lazy_secret() {
  local var=$1 item=$2
  if [[ -z ${(P)var} ]]; then
    local val
    val=$(_rbw_get_or_unlock "$item") || {
      print -u2 "rbw: failed to fetch '$item'"
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
h_cloud_age_key() { _lazy_secret SOPS_AGE_KEY    h-cloud-age-key; }
h_cloud_age_key() { _lazy_secret SOPS_AGE_KEY    h-cloud-age-key; }

# Run a command with secrets injected as env vars, fetched on demand.
# Skips items already in env, fetches the rest in parallel (~350ms total
# instead of ~350ms × N sequential).
# Usage: with-secrets <item> <ENV_VAR> [<item> <ENV_VAR> ...] -- <cmd> [args...]
with-secrets() {
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
    local -a pids vals
    for (( i = 1; i <= ${#missing_items}; i++ )); do
      vals[i]=""
      { vals[i]=$(_rbw_get_or_unlock "${missing_items[i]}"); } &!
      pids+=($!)
    done
    for (( i = 1; i <= ${#pids}; i++ )); do
      wait ${pids[i]} || true
      if [[ -z ${vals[i]} ]]; then
        print -u2 "rbw: failed to fetch '${missing_items[i]}'"
        return 1
      fi
      export "${missing_vars[i]}=${vals[i]}"
    done
  fi

  "$@"
}

fcc() {
  (
    # Fetch all keys once into this subshell
    with-secrets \
      nvidia-api-key    NVIDIA_NIM_API_KEY \
      openrouter.ai     OPENROUTER_API_KEY \
      context7-api-key  CONTEXT7_API_KEY \
      -- true

    # Start free-claude-code proxy if not already listening
    local _fcc_pid=0
    if ! lsof -i :8082 -sTCP:LISTEN &>/dev/null; then
      free-claude-code &>/dev/null &
      _fcc_pid=$!
      local _i=0
      while ! lsof -i :8082 -sTCP:LISTEN &>/dev/null && (( _i++ < 50 )); do
        sleep 0.1
      done
      if ! lsof -i :8082 -sTCP:LISTEN &>/dev/null; then
        print -u2 "fcc: proxy failed to start on :8082"
        return 1
      fi
      print -u2 "fcc: proxy started on :8082 (pid $_fcc_pid)"
    fi

    # Kill proxy on exit if we started it
    (( _fcc_pid )) && trap "kill $_fcc_pid 2>/dev/null" EXIT

    ANTHROPIC_BASE_URL="http://localhost:8082" \
    API_TIMEOUT_MS=3000000 \
    command claude "$@"
  )
}

zai() {
  (
    ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air \
    ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5-turbo \
    ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.1 \
    ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic \
    API_TIMEOUT_MS=3000000 \
    with-secrets \
      zai-api-key       ANTHROPIC_AUTH_TOKEN \
      zai-api-key       ZAI_API_KEY \
      context7-api-key  CONTEXT7_API_KEY \
      -- command claude "$@"
  )
}

sops() {
  with-secrets \
    h-cloud-age-key   SOPS_AGE_KEY \
    -- command sops "$@"
}
