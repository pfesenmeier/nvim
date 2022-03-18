#! /bin/bash

MESSAGE=$1

if [ -z "$MESSAGE" ]
	then MESSAGE="autosave (via script)"
fi

git pull

git add .
git commit -m "$MESSAGE"
git push

