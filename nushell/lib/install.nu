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
    (
      download
      LuaLS/lua-language-server 
      lua-language-server-3.7.2-win32-x64.zip
      lua-language-server.exe
    )
  } else {
    brew install lua-language-server
  }
}

def 'download omnisharp' [] {
  if $nu.os-info.family == 'windows' {
    (
      download
      OmniSharp/omnisharp-roslyn 
      omnisharp-win-x64.zip
      OmniSharp.exe
    )
  } else {
    log error "unsupported platform"
  }
}

def 'download difft' [] {
  if $nu.os-info.family == 'windows' {
    (
      download
      Wilfred/difftastic 
      difft-x86_64-pc-windows-msvc.zip
      difft.exe
    )
  } else {
    log error "unsupported platform"
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
