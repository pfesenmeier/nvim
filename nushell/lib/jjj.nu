use constants.nu wsl_distro_home

# jj helpers
export def jjj [] {}

# clone a git repository in WSL from Windows
export def "jjj wsl-clone" [
  path: string         # path to repo in WSL, relative to WSL home directory
] {
  let path = $wsl_distro_home | path join $path

  git config --global --add safe.directory ($path | path join .git)

  jj git clone $path --remote wsl
}

