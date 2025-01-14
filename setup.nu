use std log

let config_path = [$nu.home-path nvim] | path join

let neovim_config_folder = (
  (if $nu.os-info.family == 'windows' {  [AppData Local] } else { [.config] })
  | append nvim
)

let nushell_config_folder = (
  (if $nu.os-info.family == 'windows' {  [AppData Roaming] } else { [.config] })
  | append nushell
)

let alacritty_config_src = (
  if $nu.os-info.family == 'windows' {
      'alacritty.windows.toml'
  } else {
      'alacritty.linux.toml'
  }
)

let alacritty_config_dest = (
  (if $nu.os-info.family == 'windows' {  [AppData Roaming] } else { [.config] })
  | append [alacritty alacritty.toml]
)

def main [] {
    # src: relative to ~/nvim (this repo)
    # dest: relative to ~
    [{
      src: [nushell]
      dest: $nushell_config_folder
    } {
      src:  [neovim]
      dest: $neovim_config_folder
    } {
      src:  [omnisharp.json]
      dest: [.omnisharp omnisharp.json]
    } {
      src:  [wezterm.lua]
      dest: [.config wezterm wezterm.lua]
    } {
      src:  [$alacritty_config_src]
      dest: $alacritty_config_dest
    } {
      src: [whkdrc]
      dest: [.config whkdrc]
    } {
      src: [komorebi.json]
      dest: [komorebi.json]
    } {
      src: [starship.toml]
      dest: [.config starship.toml]
    } {
      src: [applications.yaml]
      dest: [applications.yaml]
    }] | each {|x| 
      let src = [$config_path] | append $x.src | path join
      let dest = [$nu.home-path] | append $x.dest | path join
    
      print $"linking ($src) to ($dest)" 

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
