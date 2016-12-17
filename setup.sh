#!/bin/bash

CURRENT_DIR=$(pwd)

DOT_FILES=(.zsh .zshrc .zshrc.alias .zshrc.linux .zshrc.osx .gitconfig .gitignore .sbtconfig .vimrc .vim .tmux.conf .dircolors)

for file in ${DOT_FILES[@]}; do 
    ln -s ${CURRENT_DIR}/$file $HOME/$file
done

case "${OSTYPE}" in
darwin*)
    brew update
    brew install scala rbenv ruby-build zsh tmux wget curl coreutils reattach-to-user-namespace
    ;;
linux*)
    ;;
esac
