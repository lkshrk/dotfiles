# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"


plugins=(
    cp
    docker
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
export HOMEBREW_NO_ENV_HINTS=TRUE

export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  #This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
source $(brew --prefix nvm)/nvm.sh


#Enable kubectl autocompletion
autoload -Uz compinit
compinit
source <(kubectl completion zsh)

export HOMEBREW_NO_ENV_HINTS=TRUE

source $HOME/.iterm2_shell_integration.zsh
source $ZSH/oh-my-zsh.sh
. $HOME/.dotfiles/.aliases
