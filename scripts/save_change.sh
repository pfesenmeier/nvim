MESSAGE=$1

if [ -z "$MESSAGE" ]
	then MESSAGE="autosave (via script)"
fi

git add .
git commit -m "$MESSAGE"
git push

