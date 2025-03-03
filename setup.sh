xcode-select --install
softwareupdate --install-rosetta
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew update

### Tools and Software
brew install fd helm jq kubernetes-cli golang mas neovim ripgrep thefuck tldr tmux tree wget yamllint yq
brew install the-unarchiver rectangle alt-tab ghostty visual-studio-code docker vivaldi google-chrome vlc franz bitwarden

brew install font-hack-nerd-font font-intel-one-mono

mas install 1352778147 #Install bitwarden

rm -rf ~/.oh-my-zsh
zsh -c "RUNZSH=no; $(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# dotfiles
rm  ~/.zshrc
cp -r -f .dotfiles $HOME/
ln -s ~/.dotfiles/.zshrc ~/.zshrc
ln -s ~/.dotfiles/.config/nvim ~/.config/nvim

### osx configs
chflags nohidden ~/Library #Show Library
defaults write com.apple.finder AppleShowAllFiles YES #Show Hidden Files
defaults write com.apple.finder ShowPathbar -bool true #Show Path Bar
defaults write com.apple.finder ShowStatusBar -bool true #Show status Bar
defaults write -g ApplePressAndHoldEnabled -bool true #Enable hold for multiple inputs
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false #Disable hold for accents in VSCode

source ~/.zshrc
