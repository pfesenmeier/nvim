# perhaps dotnet 10 has dotnet nuget install?
# https://github.com/NuGet/Home/issues/12513
# Microsoft.CodeAnalysis.LanguageServer.linux-x64

use constants.nu app_dir

const lsp_dir = $app_dir | path join "microsoft" "roslyn-lsp"

# TODO: not supporting macos intel yet
const rid = if $nu.os-info.name == "windows" {
  "win-x64"
} else if $nu.os-info.name == "macos" {
  "osx-arm64"
} else {
  "linux-x64"
}

const package_name = "Microsoft.CodeAnalysis.LanguageServer." + $rid
const downloads_folder = $nu.home-dir | path join Downloads

const download_url = "https://dev.azure.com/azure-public/vside/_artifacts/feed/vs-impl/NuGet/" + $package_name

const exe_dir = $lsp_dir | path join content LanguageServer $rid

$env.PATH = $env.PATH | prepend $exe_dir


if $nu.os-info.family != "windows" and ($env.HOMEBREW_PREFIX? | is-not-empty) {
  $env.DOTNET_ROOT = $env.HOMEBREW_PREFIX | path join opt dotnet libexec
}

const exe_name = if $nu.os-info.family == "windows" {
  "Microsoft.CodeAnalysis.LanguageServer.exe"
} else {
  "Microsoft.CodeAnalysis.LanguageServer"
}

const exe_full_path = $exe_dir | path join $exe_name

$env.ROSLYN_LSP = $exe_full_path

# run script to install roslyn lsp
export def "install roslyn-lsp" [] {
  # concat the url for the proper platform
  print "Begin try installing roslyn lsp for " + $rid

  input --numchar 1 ("Download artifact from " + $download_url + "\nPress any key to continue...")

  let downloads = (
    ls $downloads_folder 
    | where { get name | str contains $package_name }
    | sort-by modified --reverse
  )

  if ($downloads | is-empty) {
    print "No matching files found in Downloads folder for " + $package_name
    return
  }

  let download = $downloads | first | get name | path expand

  rm -rf $lsp_dir
  mkdir $lsp_dir

  unzip $download -d $lsp_dir
  chmod u+x $exe_full_path
}

# source this file to add to path
