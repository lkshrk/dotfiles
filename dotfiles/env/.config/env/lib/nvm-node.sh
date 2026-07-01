# POSIX-safe NVM Node resolver. Source from profile adapters, zsh, and hooks.

env_next_nvm_alias_target() {
  env_next_nvm_lookup="${1:-default}"
  env_next_nvm_root="${NVM_DIR:-$HOME/.nvm}"
  env_next_nvm_i=0

  while [ "$env_next_nvm_i" -lt 8 ] && [ -r "$env_next_nvm_root/alias/$env_next_nvm_lookup" ]; do
    IFS= read -r env_next_nvm_line < "$env_next_nvm_root/alias/$env_next_nvm_lookup" || return 1
    set -- $env_next_nvm_line
    env_next_nvm_lookup="${1:-}"
    [ -n "$env_next_nvm_lookup" ] || return 1
    env_next_nvm_i=$((env_next_nvm_i + 1))
  done

  printf '%s\n' "$env_next_nvm_lookup"
}

env_next_nvm_best_dir_from_candidates() {
  env_next_nvm_root="${NVM_DIR:-$HOME/.nvm}"
  env_next_nvm_best=
  env_next_nvm_best_major=-1
  env_next_nvm_best_minor=-1
  env_next_nvm_best_patch=-1

  [ -d "$env_next_nvm_root/versions/node" ] || return 1

  for env_next_nvm_candidate do
    [ -n "$env_next_nvm_candidate" ] || continue
    [ -x "$env_next_nvm_candidate/bin/node" ] || continue

    env_next_nvm_name=${env_next_nvm_candidate##*/}
    env_next_nvm_version=${env_next_nvm_name#v}
    env_next_nvm_major=${env_next_nvm_version%%.*}
    env_next_nvm_rest=${env_next_nvm_version#*.}
    [ "$env_next_nvm_rest" != "$env_next_nvm_version" ] || env_next_nvm_rest=0.0
    env_next_nvm_minor=${env_next_nvm_rest%%.*}
    env_next_nvm_patch=${env_next_nvm_rest#*.}
    [ "$env_next_nvm_patch" != "$env_next_nvm_rest" ] || env_next_nvm_patch=0
    env_next_nvm_patch=${env_next_nvm_patch%%[-+]*}

    case "$env_next_nvm_major$env_next_nvm_minor$env_next_nvm_patch" in
      ''|*[!0-9]*) continue ;;
    esac

    if [ "$env_next_nvm_major" -gt "$env_next_nvm_best_major" ] ||
       { [ "$env_next_nvm_major" -eq "$env_next_nvm_best_major" ] &&
         [ "$env_next_nvm_minor" -gt "$env_next_nvm_best_minor" ]; } ||
       { [ "$env_next_nvm_major" -eq "$env_next_nvm_best_major" ] &&
         [ "$env_next_nvm_minor" -eq "$env_next_nvm_best_minor" ] &&
         [ "$env_next_nvm_patch" -gt "$env_next_nvm_best_patch" ]; }; then
      env_next_nvm_best=$env_next_nvm_candidate
      env_next_nvm_best_major=$env_next_nvm_major
      env_next_nvm_best_minor=$env_next_nvm_minor
      env_next_nvm_best_patch=$env_next_nvm_patch
    fi
  done

  [ -n "$env_next_nvm_best" ] || return 1
  printf '%s\n' "$env_next_nvm_best"
}

env_next_nvm_resolve_dir() {
  env_next_nvm_target=$(env_next_nvm_alias_target "${1:-default}") || return 1
  env_next_nvm_root="${NVM_DIR:-$HOME/.nvm}"

  case "$env_next_nvm_target" in
    system)
      return 2
      ;;
    node|stable|unstable|lts/*)
      env_next_nvm_best_dir_from_candidates "$env_next_nvm_root"/versions/node/v*
      ;;
    v[0-9]*)
      if [ -x "$env_next_nvm_root/versions/node/$env_next_nvm_target/bin/node" ]; then
        printf '%s\n' "$env_next_nvm_root/versions/node/$env_next_nvm_target"
      else
        env_next_nvm_best_dir_from_candidates "$env_next_nvm_root"/versions/node/"$env_next_nvm_target"*
      fi
      ;;
    [0-9]*)
      env_next_nvm_best_dir_from_candidates "$env_next_nvm_root"/versions/node/v"$env_next_nvm_target"*
      ;;
    *)
      return 1
      ;;
  esac
}

env_next_nvm_resolve_bin() {
  env_next_nvm_dir=$(env_next_nvm_resolve_dir "${1:-default}") || return $?
  printf '%s/bin\n' "$env_next_nvm_dir"
}
