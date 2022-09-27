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

function prprep
  set branch $argv[1]
  if test -z $branch
    echo "Usage: git-pr-prep <branch>"
    return 1
  end

  git fetch origin $branch:$branch
  and git merge $branch --no-edit

  # affected files in PR
  and set files (git log --pretty='' --name-only $branch..HEAD | sort | uniq)
  and npm test -- --no-coverage $files

  and git diff $branch
end

# jira
alias create-pr=$HOME/nvim/jira/create-pr
alias post-slack=$HOME/nvim/jira/post-slack
alias pr-title=$HOME/nvim/jira/pr-title
  
