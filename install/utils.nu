use std log;

export def 'github install' [
  repo: string
  asset: string
  executable: string
  tag?: string
] {

    let app_dir = if $nu.os-info.family == 'windows' {
      [$nu.home-path AppData Local] | path join
    } else {
      [$nu.home-path .local bin] | path join
    }

   let install_dir = ([$app_dir $repo] | path join)

   if ($install_dir | path exists) {
      rm -rf $install_dir
   }

   (
     github download 
     $repo
     $asset
     $install_dir
     $tag
   )

   extract $install_dir $asset

   let executable = find-file $install_dir $executable;

   if not ($executable | is-empty) {

       if ($nu.os-info.family != 'windows') {
         chmod u+x $executable
       }

       print $"add ($executable | path dirname) to path \(see paths.nu\)"
   }
}

def "find-file" [
  folder: string
  file: string
] {
    let folder = $folder | path expand;

    if ($folder | path type) != 'dir' {
        log error $"expected folder but found ($folder)"
        return
    }

    let search_results = ls ($"($folder)/**/($file)" | into glob) | where type == 'file'

    if ($search_results | is-empty) {
        log error $"could not find ($file) in ($folder)"
        return
    }

    if ($search_results | length) > 1 {
        log error $"found multiple ($file) in ($folder)"
        return
    }

    $search_results | get 0.name
}

def 'github download' [
  repo: string
  file: string
  dir: string
  tag?: string
] {
  if ($tag | is-empty) {
    # creates directory path if does not exist
    run-external gh release download "--repo" $repo "--pattern" $file "--dir" $dir
  } else {
    run-external gh release download $tag "--repo" $repo "--pattern" $file "--dir" $dir
  }
}

def 'extract' [
  dir: string
  file: string
] {
  let zip_path = [$dir $file] | path join
  let ext = $zip_path | path parse | get extension;

  if $ext == 'zip' {
    run-external unzip $zip_path "-d" $dir 
  } else if ($zip_path | str ends-with 'tar.gz') {
    run-external tar "-xzf" $zip_path "-C" $dir
  } else {
    return
  }
  rm $zip_path
}
