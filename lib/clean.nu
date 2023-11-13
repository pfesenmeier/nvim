# run "jb cleanupcode" on your dotnet project
# only runs on files modified and staged
def clean [] {
  let modified = run-external --redirect-stdout "git" "diff" "--name-only" | lines;
  let staged = run-external --redirect-stdout "git" "diff" "--name-only" "--cached" | lines;

  let changed = $modified | append $staged;

  run-external "jb" "cleanupcode" '--profile"Built-in: Full Cleanup"' $changed;
}

def "clean pr" [branch: string] {
  run-external "git" "fetch" "origin" $"($branch):($branch)"
  run-external "git" "merge" $branch
  let changed = run-external --redirect-stdout "git" "diff" "--name-only" $"HEAD..($branch)" | lines;

  run-external "jb" "cleanupcode" '--profile"Built-in: Full Cleanup"' $changed;
}
