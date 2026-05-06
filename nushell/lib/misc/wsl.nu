
# determines if inside wsl
export def is_wsl []: nothing -> bool {
  $env.WSL_DISTRO_NAME? | is-not-empty
}

# finds my microsoft home account
# returns empty string if not found
export def find_ms_home []: nothing -> string {
  let known_home_dirs = [
    pfes
    pbfesenmeier
    pfesenmeier
  ]

  let home_dir_parent = '/mnt/c/Users/'

  for dir in $known_home_dirs {
    let path = $home_dir_parent | path join $dir
    let exists = $path | path exists

    if $exists {
      return $path
    }
  }

  return ""
}

