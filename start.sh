#! /bin/bash

NVIM=$HOME/nvim
NVIM_CONFIG=$HOME/.config/nvim

bash $NVIM/cargo_install.sh

# no quiet option for ln
rm $NVIM_CONFIG/init.lua
rm -r $NVIM_CONFIG/lua
rm $HOME/.bashrc

ln -s $NVIM/init.lua $NVIM_CONFIG/init.lua
ln -s $NVIM/lua $NVIM_CONFIG/lua
ln -s $NVIM/dotbashrc $HOME/.bashrc
nvim +PaqSync +qall
