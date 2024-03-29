use std log
use util.nu

# will choose first match
let pkg_managers = (
  $env.lib-path
  | append pkg-managers.csv
  | path join
  | open
  | where platform in [$nu.os-info.family, '']
)

let packages = [$env.lib-path packages.csv] | path join | open

def "ra list" [] {
  $packages 
}

def "ra install" [...names: string] {
  let pkg_list = (
    $names
    | wrap arg
    | join --left $packages arg cmd
    | filter {|it|
        if ($it.cmd | is-empty) { 
          log warning $"Program ($it.arg) not found."
          false
        } else {
          true
        }
      }
    | reject arg
    | insert pkg-manager ''
    | insert pkg-id ''
    | each {|it|
        let install_options = (
          $it 
          | select ($pkg_managers | get name) 
          | transpose pkg-manager pkg-id 
          | where pkg-id != ''
        )
        if ($install_options | is-empty) {
          log warning $"No package manager available for ($it.cmd)"
        } else {
          let selection = $install_options | first
          (
            $it
            | update pkg-manager $selection.pkg-manager
            | update pkg-id $selection.pkg-id
          )
        }
      }
    | where pkg-manager != ''
    | select pkg-manager pkg-id
  )

  if ($pkg_list | is-empty) {
    return
  }

  (
    $pkg_list
    | group-by pkg-manager
    | transpose pkg-manager pkgs
    | join --left $pkg_managers pkg-manager name
    | reject name
    | each {|it| 
        let pkgs = $it.pkgs | select pkg-id
        $it | update pkgs $pkgs
      }
    | each {|it|
        print ''
        log info $"Installing ($it.pkgs.pkg-id | str join ' ') from ($it.pkg-manager)..."
        if (($it.install-cmd | str contains ' ') == false) {
          run-external $it.pkg-manager $it.install-cmd $it.pkgs.pkg-id
        } else {
          run-external $it.pkg-manager ($it.install-cmd | split row " ") $it.pkgs.pkg-id
        }
      }
  )
  ignore
}
