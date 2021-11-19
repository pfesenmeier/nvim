#! /bin/bash

NVIM="$HOME/nvim"
rm ~/.bashrc
cp ~/nvim/dotbashrc ~/.bashrc 
source ~/.bashrc

bash $NVIM/rust.sh

rm ~/.config/nvim/init.vim -f
rm ~/.config/nvim/init.lua -f
cp "$NVIM/init.lua" ~/.config/nvim/
