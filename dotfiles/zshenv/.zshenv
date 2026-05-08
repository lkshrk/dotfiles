# Ensure Homebrew PATH for all shells (including SSH non-login shells)
if [[ -d /opt/homebrew/bin ]]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
fi
