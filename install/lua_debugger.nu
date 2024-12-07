use utils.nu

def main [] {
   let og_dir = pwd
   let app_dir = utils settings app_dir

   try {
     let install_dir = [$app_dir tomblind] | path join
     mkdir $install_dir
     cd $install_dir
     gh repo clone tomblind/local-lua-debugger-vscode
     cd local-lua-debugger-vscode
     npm install
     npm run build
     print (pwd)
     cd $og_dir
   } catch {
     print 'there was an error'
     cd $og_dir
   }
}


