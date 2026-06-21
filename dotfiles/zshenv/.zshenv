# ~/.zshenv adapter.
# Keep this tiny: every zsh process reads it, including scripts.

: "${ENV_DIR:=${ENV_NEXT_DIR:-$HOME/.config/env}}"
[ -r "$ENV_DIR/profile.sh" ] && . "$ENV_DIR/profile.sh"
