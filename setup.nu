# TODO dependent on brew, neovim, nushell...
# neovim dependent on this running
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
      src: [whkdrc]
      dest: [.config whkdrc]
    } {
      src: [komorebi.json]
      dest: [komorebi.json]
    } {
      src: [starship.toml]
      dest: [.config starship.toml]
    }] | each {|x| 
      let src = [$config_path] | append $x.src | path join
      let dest = [$nu.home-path] | append $x.dest | path join
    
      print $"linking ($src) to ($dest)" 

      idempotent_symlink $src $dest
    }

    if (which komorebic | is-not-empty) {
       komorebic fetch-app-specific-configuration
    } else {
      print "Komorebi is not installed, skipping fetch-app-specific-configuration"
    }

    if (which zoxide | is-not-empty) {
      print "installing zoxide nushell integration"
      zoxide init nushell | save -f ~/.zoxide.nu
    }
   
    [
        [nushell lib task_automation local.nu]
        [neovim lua pfes local.lua]
    ] | each {|path| 
      let path = [$config_path] | append $path | path join
     
      if not ($path | path exists) {
        print $"creating ($path)"
        mkdir $path
      } else {
        print $"($path) already exists"
      }
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
