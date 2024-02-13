def main [] {
  git branch | str replace "* " "  " | lines | str trim | where {|branch| $branch != develop and $branch != main } | each {|branch| git branch -D $branch}

}
