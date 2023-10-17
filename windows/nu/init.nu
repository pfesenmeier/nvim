let nvim_path = [$nu.home-path nvim]  
let config_path = $nvim_path | append [windows nu config]

print $config_path

def link [file_name: string] {
  let from = $config_path | append $file_name | path join
  let to = $nu.default-config-dir | append $file_name | path join
  {from: $from, to: $to}
}

let config = link 'config.nu'
let env_config = link 'env.nu'

mklink $config.to $config.from 
mklink  $env_config.to $env_config.from
