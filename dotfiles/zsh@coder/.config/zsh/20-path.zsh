path=(
  "$HOME/.local/bin"
  "$BUN_INSTALL/bin"
  "$PNPM_HOME"
  "$GOPATH/bin"
  "$HOME/.krew/bin"
  "$HOME/.cargo/bin"
  $path
)

typeset -U path
export PATH
