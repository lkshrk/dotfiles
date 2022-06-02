# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/Users/lkshrk/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"


plugins=(
    cp
    extract
    git
    history
    jsontools
    vscode
    zsh-autosuggestions
    zsh-syntax-highlighting
)

export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh

source $HOME/.iterm2_shell_integration.zsh
source $ZSH/oh-my-zsh.sh
. $HOME/.zsh_aliases
