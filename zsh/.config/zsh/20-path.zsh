# PATH composition — kept separate from env so it's easy to audit.
# Idempotent: skip dirs already on PATH.

_prepend_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

_append_path() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$PATH:$1" ;;
  esac
}

_prepend_path "$BUN_INSTALL/bin"
_prepend_path "$PNPM_HOME"
_prepend_path "${KREW_ROOT:-$HOME/.krew}/bin"
_append_path  "$GOPATH/bin"
_append_path  "$HOME/.local/bin"

unfunction _prepend_path _append_path
