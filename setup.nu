# may run with -n to skip loading on first run
use std log

const self_path = path self

def set_secrets_file [] {
  let $env_file = $self_path | path dirname | path join nushell lib secrets.nu

  if ($env_file | path exists) {
    log info "env file already exists. skipping"

  } else {
    touch $env_file
  }
}

# determines if inside wsl
def is_wsl []: nothing -> bool {
  $env.WSL_DISTRO_NAME? | is-not-empty
}

# finds my microsoft home account
# returns empty string if not found
def find_ms_home []: nothing -> string {
  let known_home_dirs = [
    pfes
    pbfesenmeier
    pfesenmeier
  ]

  let home_dir_parent = '/mnt/c/Users/'

  for dir in $known_home_dirs {
    let path = $home_dir_parent | path join $dir
    let exists = $path | path exists

    if $exists {
      return $path
    }
  }

  return ""
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

# symlinks configuration files into their expected locations
export def setup [] {
  let config_path = $nu.home-dir | path join nvim

  let neovim_config_folder = (
    (if $nu.os-info.family == 'windows' {  [AppData Local] } else { [.config] })
    | append nvim
  )

  let nushell_config_folder = (
    (if $nu.os-info.family == 'windows' {  [AppData Roaming] } else { [.config] })
    | append nushell
  )

  let ghostty_config_file = (
    if $nu.os-info.name == 'macos' {
      'ghostty.mac'
    } else {
      'ghostty.linux'
    }
  )

  let is_wsl = is_wsl
  let ms_home = find_ms_home

  log info $"is wsl: ($is_wsl)"
  if $is_wsl {
    log info $"ms home ($ms_home)"
  }

    # src: relative to ~/nvim (this repo)
    # dest: relative to ~
    [{
      src: [nushell]
      root: true
      dest: $nushell_config_folder
    } { 
      src:  [$ghostty_config_file]
      dest: [.config ghostty config]
    } {
      src:  [neovim]
      root: true
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
      src: [claude settings.json]
      dest: [.claude settings.json]
    } {
      src: [claude CLAUDE.md]
      dest: [.claude CLAUDE.md]
    } {
      src: [claude hooks]
      dest: [.claude hooks]
    } {
      src: [claude skills]
      dest: [.claude skills]
    } {
      src: [tmux.conf]
      dest: [.tmux.conf]
    }] | each {|x|
      let root = $x | get -o root | default false

      let src = if $root {
        $config_path | path join ...$x.src
      } else {
        $config_path | path join config ...$x.src
      }
      let dest = $nu.home-dir | path join ...$x.dest

      log info $"linking ($src) to ($dest)"

      idempotent_symlink $src $dest

      if $is_wsl {
        let dest = $ms_home | path join ...$x.dest

        log info $"linking ($src) to ($dest)"

        idempotent_symlink $src $dest
      }
    }

    if (which komorebic.exe | is-not-empty) {
       komorebic.exe fetch-app-specific-configuration
    } else {
      log info "Komorebi is not installed, skipping fetch-app-specific-configuration"
    }

    let zoxide_config = $nu.home-dir | path join ".zoxide.nu"

    if (which zoxide | is-not-empty) {
      log info "initializing zoxide"
      zoxide init nushell | save -f $zoxide_config
    } else if not ($zoxide_config | path exists) {
      log info "saving dummy zoxide file"
      touch $zoxide_config
    }

    # TODO (?) - does setup zoxide for windows

    set_secrets_file
}

def main [] {
  setup
}
