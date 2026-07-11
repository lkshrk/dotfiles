# ~/.bashrc — non-login bash adapter (same env spine as ~/.zshenv)

: "${ENV_DIR:=${ENV_NEXT_DIR:-$HOME/.config/env}}"
[ -r "$ENV_DIR/profile.sh" ] && . "$ENV_DIR/profile.sh"