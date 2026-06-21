_kc_cache="$HOME/.cache/zsh/kubectl-completion.zsh"
if (( $+commands[kubectl] )); then
  if [[ ! -s "$_kc_cache" || "$commands[kubectl]" -nt "$_kc_cache" ]]; then
    mkdir -p "${_kc_cache:h}"
    kubectl completion zsh > "$_kc_cache" 2>/dev/null
  fi
  source "$_kc_cache"
fi
unset _kc_cache

bun() {
  unset -f bun
  [[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"
  bun "$@"
}

_env_next_load_nvm() {
  [[ -n "${_ENV_NEXT_NVM_LOADED:-}" ]] && return 0

  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  [[ -r "$NVM_DIR/nvm.sh" ]] || return 127

  unfunction nvm 2>/dev/null || true
  source "$NVM_DIR/nvm.sh" --no-use
  _ENV_NEXT_NVM_LOADED=1
}

nvm() {
  _env_next_load_nvm || return
  nvm "$@"
}

_env_next_nvm_resolver="${ENV_DIR:-${ENV_NEXT_DIR:-$HOME/.config/env}}/lib/nvm-node.sh"
[[ -r "$_env_next_nvm_resolver" ]] && source "$_env_next_nvm_resolver"
unset _env_next_nvm_resolver

_env_next_find_nvmrc() {
  local dir="$PWD"

  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.nvmrc" ]]; then
      print -r -- "$dir/.nvmrc"
      return 0
    fi
    dir="${dir:h}"
  done

  return 1
}

_env_next_read_nvmrc_version() {
  local nvmrc="$1"
  local line

  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -n "$line" ]] || continue
    print -r -- "$line"
    return 0
  done < "$nvmrc"

  return 1
}

_env_next_set_node_bin() {
  local node_bin="$1"
  [[ -x "$node_bin/node" ]] || return 1

  path=("$node_bin" "${(@)path:#$NVM_DIR/versions/node/*/bin}")
  typeset -U path
  export PATH
  export NVM_BIN="$node_bin"
  export NVM_INC="${node_bin:h}/include/node"
  rehash
}

_env_next_use_node_fast() {
  local wanted="$1"
  local node_bin current

  (( $+functions[env_next_nvm_resolve_bin] )) || return 1
  node_bin="$(env_next_nvm_resolve_bin "$wanted" 2>/dev/null)" || return 1
  [[ -x "$node_bin/node" ]] || return 1

  current="$(command -v node 2>/dev/null || true)"
  if [[ "$current" != "$node_bin/node" || "${NVM_BIN:-}" != "$node_bin" ]]; then
    _env_next_set_node_bin "$node_bin"
  fi
}

_env_next_use_nvmrc() {
  local nvmrc wanted resolved current

  if ! nvmrc="$(_env_next_find_nvmrc)"; then
    if [[ -n "${_ENV_NEXT_NVMRC_ACTIVE:-}" ]]; then
      _env_next_use_node_fast default || {
        _env_next_load_nvm && nvm use --silent default >/dev/null 2>&1
      }
    fi
    unset _ENV_NEXT_NVMRC_ACTIVE
    return 0
  fi

  wanted="$(_env_next_read_nvmrc_version "$nvmrc")" || return 0
  [[ "$_ENV_NEXT_NVMRC_ACTIVE" == "$nvmrc:$wanted" ]] && return 0

  if _env_next_use_node_fast "$wanted"; then
    _ENV_NEXT_NVMRC_ACTIVE="$nvmrc:$wanted"
    unset _ENV_NEXT_NVMRC_MISSING
    return 0
  fi

  _env_next_load_nvm || return 0

  resolved="$(nvm version "$wanted" 2>/dev/null || true)"
  if [[ -z "$resolved" || "$resolved" == "N/A" ]]; then
    if [[ "$_ENV_NEXT_NVMRC_MISSING" != "$nvmrc:$wanted" ]]; then
      print -u2 "nvm: $wanted from $nvmrc is not installed"
      _ENV_NEXT_NVMRC_MISSING="$nvmrc:$wanted"
    fi
    _ENV_NEXT_NVMRC_ACTIVE="$nvmrc:$wanted"
    return 0
  fi

  current="$(nvm version current 2>/dev/null || true)"
  if [[ "$current" != "$resolved" || -z "${NVM_BIN:-}" ]]; then
    nvm use --silent "$wanted" >/dev/null 2>&1 || return 0
  fi

  _ENV_NEXT_NVMRC_ACTIVE="$nvmrc:$wanted"
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _env_next_use_nvmrc
_env_next_use_nvmrc
