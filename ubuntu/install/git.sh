# /usr/bin/env bash

sudo add-apt-repository ppa:git-core/ppa
sudo apt update
sudo apt install git

# no more set origin
git config --global --add --bool push.autoSetupRemote true

# setup for azure devops
git config --global credential.https://dev.azure.com.useHttpPath true

git config --global core.editor "nvim"
