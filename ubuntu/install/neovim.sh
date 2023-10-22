#! /bin/bash

set -o errexit
set -o xtrace

# neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
NVIM_PATH=/usr/bin/nvim
sudo mv -f nvim.appimage $NVIM_PATH
sudo chmod u+x $NVIM_PATH

sudo apt install fuse
