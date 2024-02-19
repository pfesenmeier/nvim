#! /usr/bin/env bash

set -o errexit

file=ripgrep_14.1.0-1_amd64.deb
wget https://github.com/BurntSushi/ripgrep/releases/latest/download/$file
sudo dpkg -i $file
rm $file
