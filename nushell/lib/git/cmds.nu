 def "g prune" [] {
   (
     run-external "git" "branch" 
     | str replace "* " "  " 
     | lines 
     | str trim 
     | where {|branch| $branch != develop and $branch != main and $branch != master } 
     | each {|branch| git branch -D $branch}   
   )
 }
