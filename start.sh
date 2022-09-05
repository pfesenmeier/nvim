#! /bin/bash

# this is a one-time setup for a new environment
# designed to be idepotent

# have neovim installed before executing
# assumes you are using fish as a daily driver

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
mkdir -p ~/.config/fish/completions
cp -f $NVIM/rg.fish ~/.config/fish/completions/
mkdir -p ~/.cargo
cp -f $NVIM/cargo_config.toml ~/.cargo/config.toml
nvim +PaqSync

