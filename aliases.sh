#! /bin/bash

alias ls=exa
alias i=exa
alias s="git status"
alias a="git add"
alias c="git commit"
alias n=nvim
alias cat=bat
alias find=fd
alias git-home="cd `git rev-parse --show-toplevel`"
git config --global alias.whereami "rev-parse --abbrev-ref HEAD"

