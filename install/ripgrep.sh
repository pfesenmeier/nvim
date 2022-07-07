#! /usr/bin/env bash

wget https://github.com/BurntSushi/ripgrep/releases/latest/download/ripgrep_13.0.0_amd64.deb

sudo dpkg -i ripgrep_13.0.0_amd64.deb
rm ripgrep_13.0.0_amd64.deb
