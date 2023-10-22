#! /bin/fish

function show
  set ARG $argv[1]

  if test -z $ARG
    ls
    return
  end

  # if folder
  if test -d $ARG
    ls $ARG
  else
    cat $ARG
  end
end

function dc
  cd $argv[1] && ls
end
  
