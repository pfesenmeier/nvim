export def jjbst- [branch: string] {
    jj bookmark set $branch -r @-
    jj bookmark track $branch
}

 # format all C# files changed since trunk
 export def fmt-changed [] {
   let root = (jj root)
   cd $root

   let files = (jj diff --summary --from "trunk()"
      | lines
      | parse "{status} {file}"
      | where file ends-with ".cs" and status != "D"
      | get file
      | each { str replace -r '\{[^=]* => ([^}]*)\}' '$1' }
      | each { |f| $"($root)/($f)" }
   )

   let slns = (
     [**/*.sln **/*.slnx]
     | each { |pat| try { ls $pat | get name } catch { [] } }
     | flatten
     | each { |s| $"($root)/($s)" }
   )

   $files
     | each { |f|
         let sln = ($slns
           | where { |s|
               let dir = ($s | path dirname)
               ($dir | is-empty) or $dir == "." or ($f | str starts-with $"($dir)/")
             }
           | sort-by { |s| $s | path dirname | str length }
           | last
         )
         { sln: $sln, file: $f }
       }
     | where sln != null
     | group-by sln --to-table
     | each { |g|
         let sln_dir = $"($g.sln | path dirname)/"
         let include = ($g.items | get file | each { str replace $sln_dir "" } | str join ";")
         try { jb cleanupcode $g.sln $"--include=($include)" --profile="Built-in: Full Cleanup" }
       }
 }
