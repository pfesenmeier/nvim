export const app_dir = if $nu.os-info.family == 'windows' {
  [$nu.home-path AppData Local] | path join
} else {
  [$nu.home-path .local bin] | path join
}

# TODO 
export const homebrew_prefix = ""

const wsl_distro = {
  name: Ubuntu-24.04
  user: pfes
}

export const wsl_distro_home = (
  '\\wsl.localhost' 
  | path join $wsl_distro.name home $wsl_distro.user
)

