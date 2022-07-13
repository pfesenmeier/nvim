#! /usr/bin/env bash

sudo apt install fd-find
mkdir -p ~/.local/bin
ln -sf $(which fdfind) ~/.local/bin/fd

# for older versions of Ubuntu
# wget https://github.com/sharkdp/fd/releases/download/v8.4.0/fd-musl_8.4.0_amd64.deb
# dpkg -i fd-musl_8.4.0_amd64.deb
# rm fd-musl_8.4.0_amd64.deb
