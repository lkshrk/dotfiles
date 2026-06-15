# Linux-specific env and PATH facts.

export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
env_next_path_prepend /home/coder/.local/bin
env_next_path_prepend "$PNPM_HOME"
