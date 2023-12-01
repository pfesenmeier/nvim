use std log

export def dump [] {
  let result = $in;
  $result | print
  $result
}

export def clip [] {
     let stdin = $in;
     if ($stdin | is-empty) {
         run-external "pwsh" "-noprofile" "-c" "Get-Clipboard"
     } else {
        run-external "pwsh" "-noprofile" "-c" $"Set-Clipboard ($stdin)"
     }
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
      | append $"$env.Path = \($env.Path | prepend ($path))" 
      | str join (char newline)
      | save -f $env_path
    )
    log info $"Successfully added ($path) to path"
  } else {
    log error "Path setting not implemented for this platform"
  }
}

export def 'github latest' [
  repo: string
  file: string
  dir: string
  tag?: string
] {

  if ($file | path parse | get extension) != 'zip' {
    log error "only zip files are supported"
    return
  } 

  if ($tag | is-empty) {
    # creates directory path if does not exist
    run-external gh release download "--repo" $repo "--pattern" $file "--dir" $dir
  } else {
    run-external gh release download $tag "--repo" $repo "--pattern" $file "--dir" $dir
  }

  let zip_path = [$dir $file] | path join
  run-external unzip $zip_path "-d" $dir 
  $zip_path | rm $in
}
