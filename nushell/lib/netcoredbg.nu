use utils.nu
use constants.nu app_dir

export def "install netcoredbg" [] {
  if $nu.os-info.family == 'windows' {
     (
       utils github install
       Samsung/netcoredbg 
       netcoredbg-win64.zip
       netcoredbg.exe
     )
    } else {
     (
       utils github install
       Samsung/netcoredbg 
       netcoredbg-linux-amd64.tar.gz
       netcoredbg
     )
  }
}

const path_dir = $app_dir | path join Samsung netcoredbg netcoredbg
$env.PATH = $env.PATH | prepend $path_dir
