use std log

let config_path = [$nu.home-path nvim] | path join

let neovim_config_folder = (
  [$nu.home-path]
  | append (if $nu.os-info.family == 'windows' {  [AppData Local] } else { [.config] })
  | append nvim
  | path join
)

def main [] {
    # ([config.nu env.nu lib] | each {|x|
    #   let source = [$config_path nu $x] | path join
    #   let dest = [$nu.default-config-dir $x] | path join
    #   idempotent_symlink $source $dest
    # })

    # src: relative to ~/nvim (this repo)
    # dest: relative to ~
    [{
      src: [nushell]
      dest: [$nu.default-config-dir]
    } {
      src:  [neovim]
      dest: $neovim_config_folder
    } {
      src:  [omnisharp.json]
      dest: [.omnisharp omnisharp.json]
    } {
      src:  [wezterm.lua]
      dest: [.config wezterm wezterm.lua]
    }] | each {|x| 
      let src = [$config_path] | append $x.src | path join
      let dest = [$nu.home-path] | append $x.dest | path join

      idempotent_symlink $src $dest
    }

    return
}

# https://www.nushell.sh/blog/2023-08-23-happy-birthday-nushell-4.html
def symlink [
    existing: path   # The existing file
    link_name: path  # The name of the symlink
] {
    let existing = ($existing | path expand -s)
    let link_name = ($link_name | path expand)

    log debug $"existing: ($existing)"
    log debug $"link name: ($link_name)"
    if $nu.os-info.family == 'windows' {
        if ($existing | path type) == 'dir' {
            mklink /D $link_name $existing
        } else {
            mklink $link_name $existing
        }
    } else {
        ln -sfv $existing $link_name | ignore
    }
}

def idempotent_symlink [source: string, dest: string] {
  let dest_dir = $dest | path dirname
  mkdir $dest_dir

  if ($dest | path exists) {
    rm --recursive $dest
  }

  symlink $source $dest
}
