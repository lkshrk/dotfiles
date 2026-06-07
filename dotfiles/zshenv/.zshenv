# ~/.zshenv -- sourced by every zsh process.
# Keep this tiny: exported env lives in ~/.config/env/profile.sh.

: "${ENV_DIR:=${ENV_NEXT_DIR:-$HOME/.config/env}}"
[ -r "$ENV_DIR/profile.sh" ] && . "$ENV_DIR/profile.sh"
