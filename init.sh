#! /bin/bash

NVIM="$HOME/nvim"
rm ~/.bashrc
cp ~/nvim/dotbashrc ~/.bashrc 
source ~/.bashrc

bash $NVIM/cargo_install.sh

rm ~/.config/nvim/init.vim -f
rm ~/.config/nvim/init.lua -f
rm -r ~/.config/nvim/lua -f
cp "$NVIM/init.lua" ~/.config/nvim/
cp -r "$NVIM/lua" ~/.config/nvim/
