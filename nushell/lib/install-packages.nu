use package_managers.nu 
use packages.nu 

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

def install-packages [manager: string, containers: list<string>, packages: list<string>] {
  let manager = get-manager $manager
  let add_container_args = $manager.add_container_cmd | split-whitespace 
  let install_args = $manager.install_cmd | split-whitespace
  let manager = $manager.name

  for container in $containers {
    ^$manager ...$add_container_args $container
  }

  if ($packages | is-not-empty) {
    ^$manager ...$install_args ...$packages
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

def available-managers [] {
  $managers | where {|manager|
    let name = $manager.name

    which $name | is-not-empty
  }
}

def get-package-column [] {
  let isLinux = $nu.os-info.name == 'linux'

  # TODO mac
  if $isLinux {
    "srcUnix"
  } else {
    "srcWindows"
  }
}

# TODO installing windows from wsl
export def "install packages" [] {
  let available_managers = available-managers 
  let src_col = get-package-column 

  let grouped_packages = (packages 
    | each {|pkg|
        let src = $pkg | get $src_col
        parse-pkg-row $pkg.name $src
      }
    | group-by manager --prune --to-table 
  )

  for group in $grouped_packages {
    let manager = $group.manager
    let containers = $group.items | get container | where $it != null | uniq 
    let packages = $group.items | get package | uniq  

    install-packages $manager $containers $packages
  }
}
