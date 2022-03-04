#! /bin/bash

NVIM=$HOME/nvim
NVIM_CONFIG=$HOME/.config/nvim

bash $NVIM/cargo_install.sh

# no quiet option for ln
# TODO install nvim latest, install oh-my-bash
rm $NVIM_CONFIG/init.lua
rm -r $NVIM_CONFIG/lua
rm $HOME/.bashrc

mkdir $NVIM
mkdir $NVIM/.config
mkdir $NVIM_CONFIG
ln -s $NVIM/init.lua $NVIM_CONFIG/init.lua
ln -s $NVIM/lua $NVIM_CONFIG/lua
ln -s $NVIM/dotbashrc $HOME/.bashrc
nvim +PaqSync +TSUpdate
