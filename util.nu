use std log

export def dump [] {
  let result = $in;
  $result | print
  $result
}

export def "env path add" [
  path: path
] {
  if ($path | path exists) == false {
    log error "Path does not exist"
    return
  }
  if $nu.os-info.family == 'windows' {
    let env_path = $nu.config-path | path basename -r ra-env.nu
    (
      $env_path
      | open
      | append $"$env.Path = \($env.Path | prepend ($path | path join))" 
      | str join 
      | save -f $env_path
    )
    log info $"Successfully added ($env.Path | get $path) to path"
  } else {
    log error "Path setting not implemented for this platform"
  }
}

# always install in user profile
# set that somewhere

# https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-win-x64-net6.0.zip
export def github latest [
  repo: string
  file: string
  dir: string
] {
  (
    if ($file | path parse | get extension) != 'zip' {
      log error "only zip files are supported"
    } else {
      # creates directory path if does not exist
      run-external gh release download "--repo" $repo "--pattern" $file "--dir" $dir

      let zip_path = [$dir $file] | path join
      run-external unzip $zip_path "-d" $dir 
      $zip_path | rm $in
    }
  )
}
