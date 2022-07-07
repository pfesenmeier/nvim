#! /bin/bash

# This is for installing things that need to be updated every month or so.

set -o errexit
set -o xtrace
set -o pipefail
set -o nounset

NVIM=$HOME/nvim
NVIM_CONFIG=$HOME/.config/nvim

mkdir -p $NVIM_CONFIG
ln -sf $NVIM/init.lua $NVIM_CONFIG/init.lua
ln -sf $NVIM/lua $NVIM_CONFIG/lua
ln -sf $NVIM/dotbashrc $HOME/.bashrc
mkdir -p $HOME/.config/fish
ln -sf $NVIM/dotfish $HOME/.config/fish/config.fish
ln -sf $NVIM/dotripgrep $HOME/.ripgreprc
mkdir ~/.config/fish/completions
cp -f rg.fish ~/.config/fish/completions/
nvim +PaqSync +TSUpdate +q

# bash $NVIM/cargo_install.sh

bash $NVIM/ra_install.sh
