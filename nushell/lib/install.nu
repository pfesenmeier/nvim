# scripts to install stuff

use util.nu

let app_dir = if $nu.os-info.family == 'windows' {
  [$nu.home-path AppData Local] | path join
} else {
  [$nu.home-path .local bin] | path join
}

def download [
  repo: string
  asset: string
  executable: string
] {
   let install_dir = ([$app_dir $repo] | path join)
   (
     util github latest 
     $repo
     $asset
     $install_dir
   )
   env path try add $install_dir $executable
}

# available in winget, but need 3.7.0 to avoid bug on windows
def 'download lua-language-server' [] {
  if $nu.os-info.family == 'windows' {
    scoop install lua-language-server
  } else {
    brew install lua-language-server
  }
}

def 'download netcoredbg' [] {
  if $nu.os-info.family == 'windows' {
    (
      download
      Samsung/netcoredbg 
      netcoredbg-win64.zip
      netcoredbg.exe
    )
  } else {
    log error "unsupported platform"
  }
}
