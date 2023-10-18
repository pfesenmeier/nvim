let config_path = [$nu.home-path nvim windows nu config]

# https://www.nushell.sh/blog/2023-08-23-happy-birthday-nushell-4.html
# Create a symlink
export def symlink [
    existing: path   # The existing file
    link_name: path  # The name of the symlink
] {
    let existing = ($existing | path expand -s)
    let link_name = ($link_name | path expand)

    if $nu.os-info.family == 'windows' {
        if ($existing | path type) == 'dir' {
            mklink /D $link_name $existing
        } else {
            mklink $link_name $existing
        }
    } else {
        ln -s $existing $link_name | ignore
    }
}

def link_nu_config [file_name: string] {
  def create-path [path:list<string>] {
    $path | append $file_name | path join
  }

  let existing = create-path $config_path
  let link_name = create-path $nu.default-config-dir

  let already_exists = $link_name | path exists
  if (not $already_exists) {
    symlink $existing $link_name 
  }
}

link_nu_config 'config.nu'
link_nu_config 'env.nu'

