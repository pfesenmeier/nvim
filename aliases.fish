#! /bin/bash

alias ls='exa -1'
alias i=ls
alias ll='exa -1la'
alias s="git status"
alias a="git add"
alias c="git commit"
alias r="git restore"
alias b="git branch"
alias tree="exa --tree"
alias e=nvim
alias g=git
alias python=python3
alias cat=bat
alias find=fd
alias f="nvim (fzf)"
alias git-home='cd `git rev-parse --show-toplevel`'
git config --global alias.whereami "rev-parse --abbrev-ref HEAD"
alias clion=clion64.exe
