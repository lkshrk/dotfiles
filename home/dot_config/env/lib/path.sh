# POSIX-safe PATH helpers for env-next.

env_next_path_remove() {
  [ -n "${1:-}" ] || return 0

  env_next_path_old=${PATH:-}
  PATH=

  while [ -n "$env_next_path_old" ]; do
    env_next_path_entry=${env_next_path_old%%:*}
    if [ "$env_next_path_old" = "$env_next_path_entry" ]; then
      env_next_path_old=
    else
      env_next_path_old=${env_next_path_old#*:}
    fi

    [ "$env_next_path_entry" = "$1" ] && continue
    PATH="${PATH:+$PATH:}$env_next_path_entry"
  done

  unset env_next_path_old env_next_path_entry
}

env_next_path_prepend() {
  [ -n "${1:-}" ] || return 0
  env_next_path_remove "$1"
  PATH="$1${PATH:+:$PATH}"
  export PATH
}

env_next_path_append() {
  [ -n "${1:-}" ] || return 0
  env_next_path_remove "$1"
  PATH="${PATH:+$PATH:}$1"
  export PATH
}
