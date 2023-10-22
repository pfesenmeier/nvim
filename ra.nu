use std log

let package_manager = (
  if $nu.os-info.family == windows { 
    'winget' 
  } else { 
    'apt' 
  }
)

# TODO: support multiple packages in single command ('unzip aws-cli')
# TODO: support script installs
# TODO: support profiles (dotnet, js, etc..)
# TODO: library for symlinking, unzipping, putting in bin folder
# TODO: common lib for neovim, ra to use (LSP_LUA_ENABLED, etc..)
# TODO: lang servers
# TODO: universal git config
let packages = [
  ['cmd'        'apt'       'winget'];
  ['rg'         'ripgrep'   'BurntSushi.ripgrep.MSVC']
  ['gk'         ''          'Axosoft.GitKraken']
  ['nvm'        ''          'CoreyButler.NVMforWindows']
  ['docker'     ''          'Docker.DockerDesktop']
  ['eza'        ''          'eza-community.eza']
  ['gh'         ''          'GitHub.cli']
  ['terraform'  ''          'Hashicorp.Terraform']
  ['jetbrains'  ''          'JetBrains.Toolbox']
  ['nvim'       ''          'Neovim.Neovim']
  ['az'         ''          'Microsoft.AzureCLI']
  ['code'       ''          'Microsoft.VisualStudioCode']
  ['obsidian'   ''          'Obsidian.Obsidian']
  ['hurl'       ''          'Orange-OpenSource.Hurl']
  ['python3'    ''          'Python.Python.3.11']
  ['starship'   ''          'Starship.Starship']
  ['zoom'       ''          'Zoom.Zoom']
  ['jq'         'jq'        'jqlang.jq']
  ['fzf'        'fzf'       'junegunn.fzf']
  ['carapace'   ''          'rsteube.Carapace']
  ['bat'        'bat'       'sharkdp.bat']
  ['fd'         'fd-find'   'sharkdp.fd']
  ['unzip'      'unzip'     '']
  ['wslu'       'wslu',     '']
  ['zig'        ''          'zig.zig']
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
          log warning $"Program ($it.argument) not found."
          return
        }

        if ($it.package_name | is-empty) {
          log warning $"No available installation method for ($it.argument)." 
          return
        }

        run-external $package_manager install $it.package_name
      }
  )
  null
}
