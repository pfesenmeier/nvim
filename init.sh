#! /bin/bash

NVIM="$HOME/nvim"
rm ~/.bashrc
cp ~/nvim/dotbashrc ~/.bashrc 
source ~/.bashrc

bash $NVIM/rust.sh

rm ~/.config/nvim/init.vim
cp "$NVIM/init.vim" ~/.config/nvim/
