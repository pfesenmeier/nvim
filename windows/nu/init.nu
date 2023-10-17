let config_path = [$nu.home-path nvim windows nu config]

def link [file_name: string] {
  def create-path [path:list<string>] {
    $path | append $file_name | path join
  }

  let from = create-path $config_path
  let to = create-path $nu.default-config-dir

  {from: $from, to: $to}
}

let config = link 'config.nu'
let env_config = link 'env.nu'

mklink $config.to $config.from 
mklink  $env_config.to $env_config.from
