$env.HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew"
$env.HOMEBREW_CELLAR = "/home/linuxbrew/.linuxbrew/Cellar"
$env.HOMEBREW_REPOSITORY = "/home/linuxbrew/.linuxbrew/Homebrew"
$env.PATH = ($env.PATH | prepend ([.local share fnm] | path join))

load-env (fnm env --shell bash
    | lines
    | str replace 'export ' ''
    | str replace -a '"' ''
    | split column =
    | rename name value
    | where name != "FNM_ARCH" and name != "PATH"
    | reduce -f {} {|it, acc| $acc | upsert $it.name $it.value }
)

$env.PATH = ($env.PATH
    | split row (char esep)
    | prepend $"($env.FNM_MULTISHELL_PATH)/bin"
)

let brew_paths = [
    "/home/linuxbrew/.linuxbrew/bin"
    "/home/linuxbrew/.linuxbrew/sbin"
]
$env.PATH = (
  $env.PATH 
  | prepend $brew_paths
  | uniq
)

if "MANPATH" in $env {
    $env.MANPATH = ($env.MANPATH | str path add "/home/linuxbrew/.linuxbrew/share/man")
} else {
    $env.MANPATH = "/home/linuxbrew/.linuxbrew/share/man"
}

if "INFOPATH" in $env {
    $env.INFOPATH = ($env.INFOPATH | str path add "/home/linuxbrew/.linuxbrew/share/info";)
} else {
    $env.INFOPATH = "/home/linuxbrew/.linuxbrew/share/info";
}

def "str path add" [path] {
    (
      $in
      | split row (char esep) 
      | prepend $path
      | uniq
      | str join esep
    )
}

