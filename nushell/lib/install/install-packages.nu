use packages/package_managers.nu
use packages/packages.nu
use ../misc/wsl.nu *

let managers = package_managers



def get-manager [name: string] {
  $managers | where name == $name | first
}

def is-single []: list<any> -> bool {
  length | let length
  $length == 1
}

def split-whitespace []: [string -> list<string>, nothing -> list<string>] {
  let input = $in | default ''

  $input | str trim | split row --regex '\s+'
}

def parse-install-cmd [cmd: string, packages: list<string>]: nothing -> list<string> {
  if ($cmd | str contains "{}") {
      let packages = $packages | str join " "
      $cmd | str replace "{}" $packages | split-whitespace
  } else {
     let $cmd = $cmd | split-whitespace
     [...$cmd, ...$packages]
  }
}

def install-packages [manager: any, containers: list<string>, packages: list<string>, use_windows_exe = false] {
  let manager = get-manager $manager
  let add_container_args = $manager.add_container_cmd | split-whitespace
  let install_multiple = $manager.install_multiple
  let install_cmd = $manager.install_cmd
  let manager = if $use_windows_exe {
    $manager.windows_exe
  } else {
    $manager.name
  }

  for container in $containers {
    ^$manager ...$add_container_args $container
  }

  if ($packages | is-not-empty) {
    print $"installing from ($manager)"
    print $"packages ($packages | str join ' ')"
    if $install_multiple {
      let install_cmd = parse-install-cmd $install_cmd $packages
      ^$manager ...$install_cmd
    } else {
      for package in $packages {
        let install_cmd = parse-install-cmd $install_cmd [$package]
        ^$manager ...$install_cmd
      }
    }
  } else {
    print $"no packages found for ($manager)"
  }
}

def create-pkg-row [manager: string, package: string, container?: string] {
  {
    manager: $manager
    package: $package
    container: $container
  }
}

# expected input: manager | manager=altname | manager=container;altname | manager=container;altname@version
# quirk: have to define altname if include container
def parse-pkg-row [package: string, input?: string] {
  if ($input | is-empty) { return }
  let input = $input | split row "="
  let manager = $input | first

  if ($input | is-single) {
    let result = create-pkg-row $manager $package
    return $result
  }

  let source = $input | get 1 | split row ';'

  if ($source | is-single) {
    let altname = $source | first
    let result = create-pkg-row $manager $altname
    return $result
  }

  let container = $source | first
  let altname = $source | get 1

  create-pkg-row $manager $altname $container
}

def get-package-column [] {
  # TODO separate mac and linux
  let isLinux = $nu.os-info.family == 'unix'

  if $isLinux {
    "srcUnix"
  } else {
    "srcWindows"
  }
}

def group_packages [src_col: string] {
  (packages
    | each {|pkg|
        let src = $pkg | get $src_col
        parse-pkg-row $pkg.name $src
      }
    | group-by manager --prune --to-table
  )
}

def install_grouped_packages [$grouped_packages: any, use_windows_exe: bool = false] {
  for group in $grouped_packages {
    let manager = $group.manager
    let containers = $group.items | get container | where $it != null | uniq
    let packages = $group.items | get package | uniq

    install-packages $manager $containers $packages $use_windows_exe
  }
}

export def "install packages" [] {
  let src_col = get-package-column
  let grouped_packages = group_packages $src_col

  install_grouped_packages $grouped_packages

  if (is_wsl) {
    print ("installing wsl")
    let grouped_packages = group_packages srcWindows
    install_grouped_packages $grouped_packages true
  }
}

def upgrade-all [manager: any, bin = "name"] {
  let bin = $manager | get $bin
  let cmd = $manager.upgrade_all_cmd | split-whitespace

  if (which $bin | is-not-empty) {
    print $"upgrading packages from ($bin)"

    ^$bin ...$cmd
  }
}

# TODO handle npm / npm.exe, dotnet / dotnet.exe
export def "install upgrades" [] {
  if ($nu.os-info.name == 'linux') {
    print "upgrading system packges. need sudo priveledges"
    sudo apt update; sudo apt upgrade -y
  }

  for manager in $managers {
    upgrade-all $manager
  }

  if (is_wsl) {
    for manager in $managers {
      upgrade-all $manager "windows_exe"
    }
  }
}


