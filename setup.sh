#!/bin/bash

CURRENT_DIR=$(cd $(dirname $0) && pwd)

DOT_FILES=(.p10k.zsh .zsh .zshrc .zshrc.alias .zshrc.common .zshrc.linux .zshrc.osx .gitconfig .gitignore .sbtconfig .vimrc .vimrc.basic .vimrc.bundle .vimrc.colors .vimrc.encoding .vimrc.plugin_setting .vimrcs.plugin.toml .vimrc.plugins_lazy.toml .vim .tmux.conf .dircolors)

for FILE in ${DOT_FILES[@]}; do 
    [ ! -f $HOME/$file ] && ln -s ${CURRENT_DIR}/$file ${HOME}/$FILE && echo "link ${CURRENT_DIR}/${FILE} -> ${HOME}/${FILE}"
done
