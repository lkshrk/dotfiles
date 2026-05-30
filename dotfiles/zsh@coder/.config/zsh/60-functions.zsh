_dotfiles_omni() {
  local dir="${DOTFILES_DIR:-$HOME/dotfiles}"
  if [[ ! -d "$dir" ]]; then
    print -u2 "dotfiles repo not found: $dir"
    return 1
  fi

  OMNI_HOSTNAME="${CODER_OMNI_HOST:-coder}" omni --config "$dir/dotfiles/omni/.config/omni/settings.json" "$@"
}

dotsync() {
  _dotfiles_omni tools sync --all
  _dotfiles_omni dots sync
}

dotcheck() {
  _dotfiles_omni tools sync --all --dry-run
  _dotfiles_omni dots sync --dry-run
}

dottrack() {
  local dir="${DOTFILES_DIR:-$HOME/dotfiles}"
  git -C "$dir" status --short
}
