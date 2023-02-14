#! /bin/fish

function show
  set ARG $argv[1]

  if test -z $ARG
    echo "usage: show <file or folder path>"
    return 
  end

  # if folder
  if test -d $ARG
    ls $ARG
  else
    cat $ARG
  end
end

