# macOS-only interactive helpers.

alias bu='brew update && brew upgrade'

# Ensure rbw is usable before git operations that need signing or SSH keys.
git() {
  case "${1:-}" in
    commit|tag|merge)
      if (( $+functions[_rbw_can_prompt] )) && _rbw_can_prompt && (( $+functions[_rbw_unlock_if_needed] )); then
        _rbw_unlock_if_needed || return
      else
        (( $+functions[_rbw_fix_ssh_auth_sock] )) && _rbw_fix_ssh_auth_sock >/dev/null 2>&1 || true
      fi
      ;;
    push|pull|fetch|clone|ls-remote|submodule)
      if (( $+functions[_rbw_can_prompt] )) && _rbw_can_prompt && (( $+functions[_rbw_ssh_agent_ready] )); then
        _rbw_ssh_agent_ready || return
      else
        (( $+functions[_rbw_fix_ssh_auth_sock] )) && _rbw_fix_ssh_auth_sock >/dev/null 2>&1 || true
      fi
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

_secure_input_pid() {
  ioreg -l -d 1 -k IOConsoleUsers 2>/dev/null \
    | sed -n 's/.*"kCGSSessionSecureInputPID"=\([0-9]*\).*/\1/p' | head -1
}

# A macOS update invalidates the event tap of a running skhd without killing it,
# so restarting the services is the fix far more often than the logout below.
fix-hotkeys() {
  emulate -L zsh

  local svc
  for svc in skhd yabai; do
    if command -v "$svc" >/dev/null 2>&1; then
      print "fix-hotkeys: restarting $svc"
      "$svc" --restart-service 2>&1 | sed "s/^/  /"
    fi
  done

  local pid; pid=$(_secure_input_pid)
  if [[ -n "$pid" && "$pid" != 0 ]]; then
    local app; app=$(ps -o comm= -p "$pid" 2>/dev/null)
    print -u2 ""
    print -u2 "\033[33m! Secure Input is held by pid $pid (${app:-unknown}).\033[0m"
    print -u2 "\033[33m  Hotkeys stay dead until it releases. Quit that app; if it won't release,\033[0m"
    print -u2 "\033[33m  fix-secure-input logs out of the GUI session as a last resort.\033[0m"
    return 1
  fi

  print ""
  print "fix-hotkeys: services restarted, no Secure Input holder."
  print "Still dead? Bisect: skhd -k \"<binding>\" (config), skhd --observe (keyboard)."
}
alias fix-skhd='fix-hotkeys'

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
