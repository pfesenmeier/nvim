if $nu.os-info.family == 'windows' {
  return
}

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

