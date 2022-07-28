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
alias ch="git checkout"
alias e=nvim
alias g=git
alias python=python3
alias cat=bat
alias pat="bat --style=plain"
alias find=fd
alias f="nvim (fzf)"
alias p="prettier -w (git diff --name-only --staged) (git diff --name-only)"
alias l="git log --oneline"
alias fac="p; a .; c"
alias git-home='cd `git rev-parse --show-toplevel`'
git config --global alias.whereami "rev-parse --abbrev-ref HEAD"
alias clion=clion64.exe
