#! /usr/bin/env bash

sudo apt install fd-find
mkdir -p ~/.local/bin
ln -sf $(which fdfind) ~/.local/bin/fd
