# ~/.bashrc — non-login bash adapter (same env spine as ~/.zshenv)

[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

: "${ENV_DIR:=${ENV_NEXT_DIR:-$HOME/.config/env}}"
[ -r "$ENV_DIR/profile.sh" ] && . "$ENV_DIR/profile.sh"

[[ $- != *i* ]] && return

[[ -n "${OMARCHY_PATH:-}" && -r "$OMARCHY_PATH/default/bash/rc" ]] && source "$OMARCHY_PATH/default/bash/rc"
