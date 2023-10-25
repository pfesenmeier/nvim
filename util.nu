use std log

export def is-non-empty [] {
  ($in | is-empty) == false
}

export def dump [] {
  let result = $in;
  $result | print
  $result
}

# problem: only works on windows
# problem: will be applied to all machines
# solution: on windows, add to calls to registry
# on linux, create linux.env.nu ??
export def "env path add" [
  path: path
] {
  if ($path | path exists) == false) {
    log error "Path does not exist"
  } else {
    open $nu.env-path | append $"$env.Path = \($env.Path | prepend ($path | path join))" | str join | save -f $nu.env-path
  }
}

# always install in user profile
# set that somewhere

# https://github.com/OmniSharp/omnisharp-roslyn/releases/latest/download/omnisharp-win-x64-net6.0.zip
# github-latest 
export def github-latest [
  repo: string
  file: path
  dir: path
] (
  if ($file | path parse | get extension) != 'zip' {
    log error "only zip files are supported"
  } else {
    # creates directory path if does not exist
    gh release download --repo $repo --pattern ($file | path join) --dir ($dir | path join)

    unzip ([$dir $file] | path join) -d $dir 
    [$dir $file] | path parse | rm $in
  }
)
