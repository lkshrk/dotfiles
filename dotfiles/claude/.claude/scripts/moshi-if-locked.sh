#!/usr/bin/env bash
# Run moshi-hooks only when the Mac screen is locked.
# macOS sets CGSSessionScreenIsLocked=true in IOConsoleUsers while locked; the
# key is absent when unlocked, so presence is a sufficient test.
# stdin (hook JSON) is forwarded to moshi-hooks when locked, discarded otherwise.
if ioreg -n Root -d1 -a 2>/dev/null | grep -q CGSSessionScreenIsLocked; then
  exec bunx moshi-hooks@latest
fi
cat >/dev/null
exit 0
