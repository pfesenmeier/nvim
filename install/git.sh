# /usr/bin/env bash

sudo add-apt-repository ppa:git-core/ppa
sudo apt update
sudo apt install git

# no more set origin
git config --global --add --bool push.autoSetupRemote true

