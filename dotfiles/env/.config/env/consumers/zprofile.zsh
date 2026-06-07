# ~/.zprofile adapter.
# Login-shell env should stay aligned with the POSIX profile adapter.

: "${ENV_DIR:=${ENV_NEXT_DIR:-$HOME/.config/env}}"
[ -r "$ENV_DIR/consumers/profile.sh" ] && . "$ENV_DIR/consumers/profile.sh"
