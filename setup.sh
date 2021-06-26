#!/bin/bash

set -e

CURRENT_DIR=$(cd $(dirname $0) && pwd)

DOT_FILES_GIT=(.gitconfig .gitignore)
DOT_FILES_ZSH=(.p10k.zsh .zsh .zshrc .zshrc.alias .zshrc.common .zshrc.linux .zshrc.osx)
DOT_FILES_SBT=(.sbtconfig)
DOT_FILES_VIM=(.vimrc .vimrc.basic .vimrc.bundle .vimrc.colors .vimrc.encoding .vimrc.plugin_setting .vimrc.plugins.toml .vimrc.plugins_lazy.toml .vim)
DOT_FILES_OTHER=(.tmux.conf .dircolors)
    
cd $HOME 

for FILE in ${DOT_FILES_GIT[@]}; do 
  [ -f $HOME/$FILE ] && rm -f $HOME/$FILE
  ln -s ${CURRENT_DIR}/$FILE .
  echo "link ${CURRENT_DIR}/${FILE} -> ${HOME}/${FILE}"
done

for FILE in ${DOT_FILES_ZSH[@]}; do 
  [ -f $HOME/$FILE ] && rm -f $HOME/$FILE
  ln -s ${CURRENT_DIR}/$FILE .
  echo "link ${CURRENT_DIR}/${FILE} -> ${HOME}/${FILE}"
done

for FILE in ${DOT_FILES_VIM[@]}; do 
   [ -f $HOME/$FILE ] && rm -f $HOME/$FILE
   ln -s ${CURRENT_DIR}/$FILE .
   echo "link ${CURRENT_DIR}/${FILE} -> ${HOME}/${FILE}"
done
