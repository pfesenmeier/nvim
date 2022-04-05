#! /usr/bin/fish

# install fish first in sudo_install file

curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
fisher install jorgebucaran/nvm.fish
nvm install lts/gallium
