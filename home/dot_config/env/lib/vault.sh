# Bitwarden lookups shared by vault-env and vault-get; callers export BW_SESSION and source this file.

# bw starts the desktop app's proxy for every command and never exits while it runs; only unlock needs it.
vault_bw() {
  BITWARDEN_DESKTOP_PROXY_PATH=/nonexistent/bitwarden-desktop-proxy bw "$@"
}

# Sets items and folders; the two lists run in parallel since each bw call takes seconds.
vault_bw_load() {
  vault_bw_folders_file=$(mktemp) || return 1
  vault_bw list folders >"$vault_bw_folders_file" 2>/dev/null &
  vault_bw_folders_pid=$!
  items=$(vault_bw list items ${1:+--search "$1"} 2>/dev/null)
  vault_bw_items_rc=$?
  wait "$vault_bw_folders_pid"
  vault_bw_folders_rc=$?
  folders=$(cat "$vault_bw_folders_file")
  rm -f "$vault_bw_folders_file"
  [ "$vault_bw_items_rc" = 0 ] && [ "$vault_bw_folders_rc" = 0 ]
}

# Prints FIELD of the one item named ITEM or FOLDER/NAME (a password falls back to notes, like rbw get).
vault_bw_value() {
  printf '%s' "$1" | jq -er --argjson folders "$2" --arg field "$3" --arg item "$4" '
    ($item | if contains("/") then [split("/")[0], (split("/")[1:] | join("/"))] else [null, .] end) as [$folder, $name]
    | ($folders | map(select(.name == $folder) | .id)) as $ids
    | [.[] | select(.name == $name and ($folder == null or (.folderId as $id | $ids | index($id) != null)))]
    | if length == 1 then .[0] else error("\(length) items match") end
    | if $field == "username" then .login.username
      elif $field == "notes" then .notes
      else (.login.password // .notes) end
    | select(. != null and . != "")' 2>/dev/null
}
