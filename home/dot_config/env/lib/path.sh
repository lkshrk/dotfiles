# POSIX-safe PATH helpers.

env_path_remove() {
  [ -n "${1:-}" ] || return 0

  env_path_old=${PATH:-}
  # shellcheck disable=SC2123
  PATH=

  while [ -n "$env_path_old" ]; do
    env_path_entry=${env_path_old%%:*}
    if [ "$env_path_old" = "$env_path_entry" ]; then
      env_path_old=
    else
      env_path_old=${env_path_old#*:}
    fi

    [ "$env_path_entry" = "$1" ] && continue
    PATH="${PATH:+$PATH:}$env_path_entry"
  done

  unset env_path_old env_path_entry
}

env_path_prepend() {
  [ -n "${1:-}" ] || return 0
  env_path_remove "$1"
  PATH="$1${PATH:+:$PATH}"
  export PATH
}

env_path_append() {
  [ -n "${1:-}" ] || return 0
  env_path_remove "$1"
  PATH="${PATH:+$PATH:}$1"
  export PATH
}
