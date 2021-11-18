#! /bin/bash

NVIM_FOLDER="$HOME/nvim"

nvim:init () {
  source "$NVIM_FOLDER/init.sh"
}

nvim:update () {
  CUR_DIR=$(pwd)
  cd ~/nvim
  git pull -q
  nvim:init
  cd $CUR_DIR
}

nvim:save () {
  MESSAGE=$1
  if [ -z "$MESSAGE" ]
    then MESSAGE="autosave (via script)"
  fi

  git add .
  git commit -m "$MESSAGE"
  git push
}

