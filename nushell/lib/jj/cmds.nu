export def jjbst- [branch: string] {
    jj bookmark set $branch -r @-
    jj bookmark track $branch -r @-
}

 # format all C# files changed since trunk
 export def fmt-changed [] {
   let files = (jj diff --summary --from "trunk()"
      | lines
      | parse "{status} {file}"
      | where file ends-with ".cs"
      | where file ends-with ".cs" and status != "D"
      | get file
      | each { str replace -r '\{[^=]* => ([^}]*)\}' '$1' }
   )

   csharpier format ...$files
 }
