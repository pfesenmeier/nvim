use std log
use util.nu

let sys_pkg_manager = (
  if $nu.os-info.family == windows { 
    'winget' 
  } else { 
    'apt' 
  }
)

# list in order of precedence
let pkg_managers = [
  ['name' 'install-args' 'platform'];
  ['winget' '' 'windows']
  # TODO: what is $nu.os-info.family for linux?
  ['apt' '' 'linux']
  ['npm' '-g' '']
] | where {|it| (
      $it.platform == $nu.os-info.family
      ) or (
      $it.platform | is-empty
      )
    }

# TODO: support script installs
# TODO: support profiles (dotnet, js, etc..)
# TODO: library for symlinking, unzipping, putting in bin folder
# TODO: common lib for neovim, ra to use (LSP_LUA_ENABLED, etc..)
# TODO: lang servers
# TODO: universal git config
# TODO: move tables to csv
let packages = [
  ['cmd'        'apt'       'winget'                        'npm'   ];
  ['az'         ''          'Microsoft.AzureCLI' '']
  ['bat'        'bat'       'sharkdp.bat' '']
  ['bash-language-server' '' '' 'bash-language-server']
  ['carapace'   ''          'rsteube.Carapace' '']
  ['code'       ''          'Microsoft.VisualStudioCode' '']
  ['docker'     ''          'Docker.DockerDesktop' '']
  ['eza'        ''          'eza-community.eza' '']
  ['fd'         'fd-find'   'sharkdp.fd' '']
  ['fzf'        'fzf'       'junegunn.fzf' ''      ]
  ['gh'         ''          'GitHub.cli' ''      ]
  ['gk'         ''          'Axosoft.GitKraken' ''      ]
  ['hurl'       ''          'Orange-OpenSource.Hurl' ''      ]
  ['jetbrains'  ''          'JetBrains.Toolbox' ''      ]
  ['jq'         'jq'        'jqlang.jq' '' ]
  ['nvim'       ''          'Neovim.Neovim' '' ]
  ['nvm'        ''          'CoreyButler.NVMforWindows'     ''      ]
  ['obsidian'   ''          'Obsidian.Obsidian' '' ]
  ['python3'    ''          'Python.Python.3.11' '' ]
  ['rg'         'ripgrep'   'BurntSushi.ripgrep.MSVC'       ''      ]
  ['starship'   ''          'Starship.Starship' '' ]
  ['terraform'  ''          'Hashicorp.Terraform' '' ]
  ['unzip'      'unzip'     '' '' ]
  ['wslu'       'wslu',     '' '' ]
  ['zig'        ''          'zig.zig' '' ]
  ['zoom'       ''          'Zoom.Zoom' '' ]
]

def "ra list" [] {
  $packages 
}

def "ra install" [...names: string] {
  (
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
          | where {|it| $it.pkg-id | util is-non-empty } 
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
    | filter {|it| $it.pkg-manager | util is-non-empty}
    | select cmd pkg-manager pkg-id
    | group-by pkg-manager
    | transpose pkg-manager pkgs
    | join --left $pkg_managers pkg-manager name
    | reject name
    | each {|it| 
        let pkgs = $it.pkgs | select cmd pkg-id
        $it | update pkgs $pkgs
      }
    | each {|it|
        print ''
        log info $"Installing ($it.pkgs.pkg-id | str join ' ') from ($it.pkg-manager)..."
        if ($it.install-args | is-empty) {
          run-external $it.pkg-manager install $it.pkgs.pkg-id
        } else {
          run-external $it.pkg-manager install $it.install-args $it.pkgs.pkg-id
        }
      }
  )
  ignore
}
