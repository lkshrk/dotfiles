#!/usr/bin/env bash
# scripts/macos-defaults.sh — system tweaks. Idempotent.

set -euo pipefail

# Finder
chflags nohidden ~/Library                                # show ~/Library
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar      -bool true
defaults write com.apple.finder ShowStatusBar    -bool true

# Keyboard — enable hold for multiple inputs (vim users), disable in VSCode
defaults write -g                       ApplePressAndHoldEnabled -bool true
defaults write com.microsoft.VSCode     ApplePressAndHoldEnabled -bool false

killall Finder 2>/dev/null || true
echo "macOS defaults applied. Some changes require logout to take effect."
