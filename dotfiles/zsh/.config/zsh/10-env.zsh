# Interactive-only. Exported env vars and PATH live in env-next/profile.sh,
# loaded by shell adapters. Keep only interactive session behavior here.

# Window title: "folder" locally, "host:folder" over SSH
_update_title() {
  local title="${PWD##*/}"
  [[ -n $SSH_CONNECTION ]] && title="${HOST%%.*}:$title"
  printf '\033]2;%s\007' "$title"
}
precmd_functions+=(_update_title)
chpwd_functions+=(_update_title)
