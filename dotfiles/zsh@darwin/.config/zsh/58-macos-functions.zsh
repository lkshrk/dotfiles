# macOS-only interactive helpers.

alias bu='brew update && brew upgrade'

# Ensure rbw is unlocked before signing operations so GPG can fetch the key.
git() {
  case "${1:-}" in
    commit|tag|merge)
      (( $+functions[_rbw_unlock_if_needed] )) && _rbw_unlock_if_needed
      ;;
  esac
  command git "$@"
}

# Refresh yabai's sudoers entry after Homebrew actions that can replace the
# yabai binary. The script is idempotent and quiet when the hash is current.
brew() {
  command brew "$@"
  local rc=$?

  case "${1:-}" in
    install|upgrade|reinstall|bundle)
      local script="$HOME/.config/yabai/update_sudoers.sh"
      [[ -x "$script" ]] || return $rc
      command -v yabai >/dev/null 2>&1 || return $rc
      local out
      out=$("$script" 2>&1) || true
      [[ -n "$out" ]] || return $rc
      print -u2 ""
      print -u2 "\033[33m$out\033[0m"
      if command -v csrutil >/dev/null 2>&1; then
        local sip_status
        sip_status=$(csrutil status 2>/dev/null)
        if [[ "$sip_status" != *"disabled"* && "$sip_status" != *"Custom Configuration"* ]]; then
          print -u2 "\033[33m! yabai --load-sa requires SIP partially disabled.\033[0m"
          print -u2 "\033[33m  Boot to recovery -> Terminal:\033[0m"
          print -u2 "\033[33m  csrutil disable --with-kext --with-dtrace --with-nvram --with-basesystem\033[0m"
        fi
      fi
      ;;
  esac
  return $rc
}

fix-secure-input() {
  emulate -L zsh

  if [[ "${1:-}" != "--yes" ]]; then
    print "fix-secure-input: this logs out of the macOS GUI session."
    printf "Continue? [y/N] "
    local reply
    read -r reply
    [[ $reply == [yY]* ]] || { print "fix-secure-input: aborted"; return 1; }
  fi

  osascript -e 'tell application "System Events" to log out'
}
alias fix-skhd='fix-secure-input'

swap-keys() {
  hidutil property --set '{
    "UserKeyMapping": [
      {
        "HIDKeyboardModifierMappingSrc": 0x700000064,
        "HIDKeyboardModifierMappingDst": 0x700000035
      },
      {
        "HIDKeyboardModifierMappingSrc": 0x700000035,
        "HIDKeyboardModifierMappingDst": 0x700000064
      }
    ]
  }'
}
