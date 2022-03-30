#! /usr/bin/fish

set NVIM_FOLDER "$HOME/nvim"

function nvim_sync 
  set CUR_DIR $(pwd)
  set MESSAGE $1

  if test -n MESSAGE
    set MESSAGE "autosave (via script)"
  end

  cd $NVIM_FOLDER
  git pull
  git add .
  git commit -m "$MESSAGE"
  git push
  cd $CUR_DIR
end
