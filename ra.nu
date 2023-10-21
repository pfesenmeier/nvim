use std log

let package_manager = (
  if $nu.os-info.family == windows { 
    "winget" 
  } else { 
    "apt" 
  }
)

let packages = [
  [cmd, "apt", "winget"];
  [rg, ripgrep, BurntSushi.ripgrep.MSVC]
  [fd,'','']
]

def "ra list" [] {
  $packages 
}


def "ra install" [...names:string] {
  (
    $names 
    | wrap argument
    | join --left $packages argument cmd
    | select argument cmd $package_manager
    | rename --column { $package_manager: package_name }
    | each {|it|
        if ($it.cmd | is-empty) { 
          log warning $"Program "($it.argument)" not found."
          return
        }

        if ($it.package_name | is-empty) {
          log warning $"No available installation method for "($it.argument)"." 
          return
        }

        run-external $package_manager install $it.package_name
      }
  )
  null
}
