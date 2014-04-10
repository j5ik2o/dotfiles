#!/bin/bash

DOT_FILES=(.zsh .zshrc .zshrc.alias .zshrc.linux .zshrc.osx .gitconfig .gitignore .sbtconfig .vimrc .vim .tmux.conf .dircolors)

for file in ${DOT_FILES[@]}; do 
    ln -s $HOME/dotfiles/$file $HOME/$file
done

[ ! -d ~/.oh-my-zsh ] && git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh

[ ! -d ~/.vim/bundle ] && mkdir -p ~/.vim/bundle && git clone git://github.com/Shougo/neobundle.vim ~/.vim/bundle/neobundle.vim && vim -c ':NeoBundleInstall'

[ ! -d ~/.nvm ] && git clone git://github.com/creationix/nvm.git ~/.nvm

case "${OSTYPE}" in
darwin*)
    brew update
    brew tap josegonzalez/php
    brew install scala rbenv ruby-build zsh tmux wget curl coreutils reattach-to-user-namespace
    ;;
linux*)
    ;;
esac
