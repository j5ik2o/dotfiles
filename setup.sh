#!/bin/bash

CURRENT_DIR=$(cd $(dirname $0) && pwd)

mkdir -p ~/.vim/bundle
git clone https://github.com/Shougo/neobundle.vim ~/.vim/bundle/neobundle.vim

curl -L git.io/nodebrew | perl - setup

DOT_FILES=(.zsh .zshrc .zshrc.alias .zshrc.linux .zshrc.osx .gitconfig .gitignore .sbtconfig .vimrc .vimrc.basic .vimrc.bundle .vimrc.colors .vimrc.encoding .vimrc.plugin_setting .vim .tmux.conf .dircolors)

for file in ${DOT_FILES[@]}; do 
    ln -s ${CURRENT_DIR}/$file $HOME/$file
done

case "${OSTYPE}" in
darwin*)
    brew update
    brew bundle
    ;;
linux*)
    ;;
esac
