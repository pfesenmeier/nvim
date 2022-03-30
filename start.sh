#! /bin/bash

set -o errexit
set -o xtrace
set -o pipefail
set -o nounset

NVIM=$HOME/nvim
NVIM_CONFIG=$HOME/.config/nvim

bash $NVIM/cargo_install.sh

# no quiet option for ln
# TODO install nvim latest, install oh-my-bash
# TODO use mkdir -p
rm -f $NVIM_CONFIG/init.lua
rm -rf $NVIM_CONFIG/lua
rm -rf $HOME/.bashrc

if [ ! -d $HOME/.config ]; then
  mkdir $HOME/.config
fi
if [ ! -d $NVIM_CONFIG ]; then
  mkdir $NVIM_CONFIG
fi
ln -s $NVIM/init.lua $NVIM_CONFIG/init.lua
ln -s $NVIM/lua $NVIM_CONFIG/lua
ln -s $NVIM/dotbashrc $HOME/.bashrc
nvim +PaqSync +TSUpdate

# download latest rust-analyzer binary
mkdir -p ~/.local/bin
curl -L https://github.com/rust-analyzer/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-unknown-linux-gnu.gz | gunzip -c - > ~/.local/bin/rust-analyzer
chmod +x ~/.local/bin/rust-analyzer
