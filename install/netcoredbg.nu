use utils.nu;

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
