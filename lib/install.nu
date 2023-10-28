# scripts to install stuff

use util.nu

let app_dir = if $nu.os-info.family == 'windows' {
  [$nu.home-path AppData Local] | path join
} else {
  [$nu.home-path .local bin] | path join
}

# https://github.com/LuaLS/lua-language-server/releases/tag/3.7.0
# available in winget, but need 3.7.0 to avoid bug on windows
# TODO: tar.gz files and linux
def 'download lua-language-server' [] {
 let install_dir = [$app_dir lua-language-server] 
 
 (
   util github latest 
   LuaLS/lua-language-server 
   lua-language-server-3.7.0-win32-x64.zip 
   ($install_dir | path join)
 )

 util env path add ($install_dir | append bin | path join)
}

def 'download omnisharp' [] {
 let install_dir = [$app_dir omnisharp] | path join
 
 (
   util github latest 
   OmniSharp/omnisharp-roslyn 
   omnisharp-win-x64.zip
   $install_dir
 )

 util env path add $install_dir
}

def 'download difft' [] {
 let install_dir = [$app_dir difft] | path join
 
 (
   util github latest 
   Wilfred/difftastic 
   difft-x86_64-pc-windows-msvc.zip
   $install_dir
 )

 util env path add $install_dir
}
