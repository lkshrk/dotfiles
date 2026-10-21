# ~/.bashrc on Omarchy — Omarchy's bash defaults plus the shared env spine.
# zsh is the login shell; this keeps interactive bash (and Omarchy's own
# scripts that spawn one) behaving like a stock Omarchy shell.

# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

: "${ENV_DIR:=${ENV_NEXT_DIR:-$HOME/.config/env}}"
[ -r "$ENV_DIR/profile.sh" ] && . "$ENV_DIR/profile.sh"

[[ $- != *i* ]] && return

# Omarchy's aliases and functions
source "$OMARCHY_PATH/default/bash/rc"
