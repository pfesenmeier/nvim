use constants.nu app_dir

const roslynator_dir = $app_dir | path join dotnet roslynator

export def "install roslynator" [] {
   let zip = 'roslynator.zip'    
   let exdir = 'roslynator'
   const home = $nu.home-path

   # when worked with omnisharp
   # let dest = $home | path join '.omnisharp' roslynator
   let dest = $roslynator_dir

   def cleanup [] {
     if ($zip | path exists) {
         rm $zip
     }

     if ($exdir | path exists) {
         rm -rf $exdir
     }
   }

   cleanup
   mkdir $dest
   mkdir $exdir

   curl -Lo $zip https://open-vsx.org/api/josefpihrt-vscode/roslynator/4.14.0/file/josefpihrt-vscode.roslynator-4.14.0.vsix
   unzip -o $zip -d $exdir

   let dlls = $"($exdir)/**/*.dll" | into glob 
   ls $dlls | each {|dll| print $dll; print $dest; cp $dll.name $dest }
   cleanup
   ls $dest
}

$env.ROSLYNATOR_DIR = $roslynator_dir
