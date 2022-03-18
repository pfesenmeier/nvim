#! /bin/bash

# https://kvz.io/bash-best-practices.html
# set -o errexit
# set -o nounset
# set -o pipefail
# set -o xtrace

NVIM_FOLDER="$HOME/nvim"

nvim:start () {
  source "$NVIM_FOLDER/start.sh"
}

nvim:reload () {
  CUR_DIR=$(pwd)
  cd $NVIM_FOLDER
  git pull -q
  nvim:start
  cd $CUR_DIR
}

nvim:sync () {
  CUR_DIR=$(pwd)
  MESSAGE=$1
  if [ -z "$MESSAGE" ]
    then MESSAGE="autosave (via script)"
  fi

  cd $NVIM_FOLDER
  git pull
  git add .
  git commit -m "$MESSAGE"
  git push
  cd $CUR_DIR
}
