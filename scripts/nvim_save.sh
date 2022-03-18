#! /bin/bash

MESSAGE=$1

if [ -z "$MESSAGE" ]
	then MESSAGE="autosave (via script)"
fi

cwd=$(pwd)

cd ~/nvim

git pull
git add .
git commit -m "$MESSAGE"
git push

cd $cwd

