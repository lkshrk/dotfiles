# Interactive-only. Exported env vars and PATH live in env-next/profile.sh,
# loaded by shell adapters. Keep only interactive session behavior here.

# Window title: "folder" locally, "host:folder" over SSH
_update_title() {
  local title="${PWD##*/}"
  [[ -n $SSH_CONNECTION ]] && title="${HOST%%.*}:$title"
  printf '\033]2;%s\007' "$title"
}
# tmux copies an SSH client's env into new panes, which drops the local Wayland session that clipboard tools need.
if [[ -z ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} ]]; then
  _wl_sockets=("$XDG_RUNTIME_DIR"/wayland-<->(N=))
  (( $#_wl_sockets )) && export WAYLAND_DISPLAY=${_wl_sockets[1]:t}
  unset _wl_sockets
fi

precmd_functions+=(_update_title)
chpwd_functions+=(_update_title)
