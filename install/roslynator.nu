def main [] {
   let zip = 'roslynator.zip'    
   let exdir = 'roslynator'
   let home = $env.HOME? | default $env.USERPROFILE? 

   if ($home | is-empty) {
       error make { msg: "could not determine home dir" }
   }

   let dest = $home | path join '.omnisharp' roslynator

   def cleanup [] {
     if ($zip | path exists) {
         rm $zip
     }

     if ($exdir | path exists) {
         rm -rf $exdir
     }
   }

   try {
       cleanup
       mkdir $dest
       mkdir $exdir

       curl -Lo $zip https://open-vsx.org/api/josefpihrt-vscode/roslynator/4.12.4/file/josefpihrt-vscode.roslynator-4.12.4.vsix
       unzip -o $zip -d $exdir

       let dlls = $"($exdir)/**/*.dll" | into glob 
       ls $dlls | get name | each { print $in; print $dest; cp $in $dest }
       cleanup
       ls $dest
   } catch {|err|
       cleanup
       print "error occurred"
       print -e $err
       exit 1
   }
}
