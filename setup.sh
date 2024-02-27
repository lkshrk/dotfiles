xcode-select --install
softwareupdate --install-rosetta
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew update

### Tools and Software
brew install fd ffmpeg golang helm jq kubernetes-cli mas neovim nvm pipx python ripgrep thefuck tldr tmux tree wget yamllint youtube-dl yq
brew install the-unarchiver amphetamine rectangle alt-tab iterm2 appcleaner visual-studio-code docker microsoft-edge google-chrome vlc franz

brew tap homebrew/cask-fonts
brew install font-hack-nerd-font font-intel-one-mono

pipx ensurepath
mkdir ~/.nvm

mas signin harkelukas@googlemail.com
mas install 1352778147 #Install bitwarden


sh -c "RUNZSH=no; $(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# dotfiles
cp -r -f .dotfiles $HOME/
ln -s ~/.dotiles/.zshrc ~/.zshrc
ln -s ~/.dotfiles/.config/nvim ~/.config/nvim

### osx configs
chflags nohidden ~/Library #Show Library
defaults write com.apple.finder AppleShowAllFiles YES #Show Hidden Files
defaults write com.apple.finder ShowPathbar -bool true #Show Path Bar
defaults write com.apple.finder ShowStatusBar -bool true #Show status Bar
defaults write -g ApplePressAndHoldEnabled -bool #Enable hold for multiple inputs
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false #Disable hold for accents in VSCode

source ~/.zshrc