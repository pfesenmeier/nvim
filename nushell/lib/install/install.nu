# scripts to install stuff

let app_dir = if $nu.os-info.family == 'windows' {
  [$nu.home-dir AppData Local] | path join
} else {
  [$nu.home-dir .local bin] | path join
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
