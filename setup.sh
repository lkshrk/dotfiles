xcode-select --install
softwareupdate --install-rosetta
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew update

### Tools and Software
brew install golang ffmpeg lame tree vim wget youtube-dl tmux mas python pyenv thefuck watch tldr yamllint
brew install iina little-snitch the-unarchiver alt-tab hammerspoon karabiner-elements iterm2 appcleaner vlc \
visual-studio-code docker \
telegram whatsapp firefox google-chrome signal discord \
steelseries-exactmouse-tool logitech-g-hub


sh -c "RUNZSH=no; $(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting


brew tap homebrew/cask-fonts
brew install font-hack-nerd-font

# dotfiles for zsh
cp -r -f dotfiles/ $HOME/

### osx configs
chflags nohidden ~/Library #Show Library
defaults write com.apple.finder AppleShowAllFiles YES #Show Hidden Files
defaults write com.apple.finder ShowPathbar -bool true #Show Path Bar
defaults write com.apple.finder ShowStatusBar -bool true #Show status Bar
