#! /bin/bash

set -o errexit
set -o xtrace

# neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
NVIM_PATH=/usr/bin/nvim
sudo rm $NVIM_PATH
sudo mv nvim.appimage $NVIM_PATH
sudo chmod u+x $NVIM_PATH
