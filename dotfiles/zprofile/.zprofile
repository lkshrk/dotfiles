# ~/.zprofile -- login zsh adapter.

: "${ENV_DIR:=${ENV_NEXT_DIR:-$HOME/.config/env}}"
[ -r "$ENV_DIR/consumers/zprofile.zsh" ] && . "$ENV_DIR/consumers/zprofile.zsh"
