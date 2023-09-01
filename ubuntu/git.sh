#! /usr/bin/env bash

git config --global core.editor "nvim"
git config --global user.name "Paul Fesenmeier"
git config --global user.email pfesenmeier@gmail.com
git config --global alias.chcekout checkout
git config --global alias.checkoud checkout

git config --global diff.external difft

# useful for BitBucket logins
# install Git for Windows first
# commented out for now -> using gh tool to login to github
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"

# git config --global --unset credential.helper

