use std log

export def dump [] {
  let result = $in;
  $result | print
  $result
}

export def "env path try add" [
  folder: string
  file: string
] {
  if ($folder | path type) != 'dir' {
    log error $"folder ($folder) does not exist"
    return
  }

  let search_results = ls $"($folder)/**/($file)"

  if ($search_results | is-empty) {
    log error $"could not find ($file) in ($folder)"
    return
  }

  let file = $search_results | get 0.name
  let base_path = $file | path dirname

  env path add $base_path
}

export def "env path add" [
  path: string
] {
  if ($path | path exists) == false {
    log error "Path does not exist"
    return
  }
  if $nu.os-info.family == 'windows' {
    let env_path = $nu.config-path | path basename -r lib | path join ra-env.nu

    if ($env_path | path exists) == false {
      touch $env_path
    }

    (
      $env_path
      | open
      | append $"$env.PATH = \($env.PATH | prepend ($path))" 
      | str join (char newline)
      | save -f $env_path
    )
    log info $"Successfully added ($path) to path"
  } else {
    log error "Path setting not implemented for this platform"
  }
}

# always install in user profile
# set that somewhere

# https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-win-x64-net6.0.zip
export def 'github latest' [
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
