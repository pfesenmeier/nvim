if $nu.os-info.family == 'windows' {
  return
}

if (which brew | is-not-empty) {
  $env.HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew"
  $env.HOMEBREW_CELLAR = "/home/linuxbrew/.linuxbrew/Cellar"
  $env.HOMEBREW_REPOSITORY = "/home/linuxbrew/.linuxbrew/Homebrew"
  let brew_paths = [
      "/home/linuxbrew/.linuxbrew/bin"
      "/home/linuxbrew/.linuxbrew/sbin"
  ]
  $env.PATH = (
    $env.PATH 
    | prepend $brew_paths
    | uniq
  )

  $env.MANPATH = ($env.MANPATH? | concat-paths "/home/linuxbrew/.linuxbrew/share/man")
  $env.INFOPATH = ($env.INFOPATH? | concat-paths  "/home/linuxbrew/.linuxbrew/share/info")
}

if (which fnm | is-not-empty) {
  if ($env.FNM_MULTISHELL_PATH | is-not-empty) {
    $env.PATH = ($env.PATH
        | split row (char esep)
        | prepend $"($env.FNM_MULTISHELL_PATH)/bin"
    )
  }

  load-env (fnm env --shell bash
      | lines
      | str replace 'export ' ''
      | str replace -a '"' ''
      | split column "=" 
      | rename name value
      | where name != "FNM_ARCH" and name != "PATH"
      | reduce -f {} {|it, acc| $acc | upsert $it.name $it.value }
  )
}

def "concat-paths" [...path] {
    let current = if ($in | is-not-empty) {
      $in | split row (char esep)
    } else {
      []
    }

    (
      $current  
      | prepend $path
      | uniq
      | str join (char esep)
    )
}

