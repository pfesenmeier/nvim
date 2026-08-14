# may run with -n to skip loading on first run
use std/log

const self_path = path self

def check-pinentry [] {
  if $nu.os-info.name == "linux" and (which pinentry-gnome3 | is-empty) {
    log warning "pinentry-gnome3 is not installed on this system"
    log warning "install with 'sudo apt install pinentry-gnome3'"
  }
}

def set_secrets_file [] {
  let $env_file = $self_path | path dirname | path join nushell lib secrets.nu

  if ($env_file | path exists) {
    log info "env file already exists. skipping"

  } else {
    touch $env_file
  }
}

# the folder itself cannot be symlinked,
# because self-installed programs depend on it (e.g. roslyn lsp)
def symlink_local_bins [] {
  let srcs = $self_path | path dirname | path join bin
  let srcs = glob ($srcs + "/*")

  let dest_dir = $nu.home-dir | path join .local bin

  $srcs | each {|src|
    let dest = $src | path basename
    let dest = $dest_dir | path join $dest

    log info $"linking ($src) to ($dest)"
    idempotent_symlink $src $dest
  }
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
    (if $nu.os-info.family == 'windows' {
        [AppData Roaming]
     } else if $nu.os-info.name == 'macos' {
        [Library 'Application Support']
      } else {
       [.config]
     }
    )
    | append nushell
  )

  let ghostty_config_file = (
    if $nu.os-info.name == 'macos' {
      'ghostty.mac'
    } else {
      'ghostty.linux'
    }
  )

  let gpg_config_file = (
    if $nu.os-info.name == 'macos' {
      'gpg-agent.conf.mac'
    } else {
      'gpg-agent.conf'
    }
  )

    # root: true -> src relative to ~/nvim/config
    # root: false -> src relative to ~/nvim
    # dest: relative to ~
    # plat: platform (must match $nu.os-info.name: macos, windows, linux
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
      plat: windows
    } {
      src: [claude settings.json]
      dest: [.claude settings.json]
    } {
      src: [claude CLAUDE.md]
      dest: [.claude CLAUDE.md]
    } {
      src: [claude skills]
      dest: [.claude skills]
    } {
      src: [jjui]
      dest: [.config jjui]
    } {
      src: [jj config.toml]
      dest: [.config jj config.toml]
    } {
      src: [komorebi-mac]
      dest: [.config komorebi]
      plat: macos
    } {
      src: [skhdrc]
      dest: [.config skhd skhdrc]
      plat: macos
    } {
      src: [$gpg_config_file]
      dest: [.gnupg gpg-agent.conf]
    }] | each {|x|
      let plat_supported = (
        $x | get plat?
        | default $nu.os-info.name
        | $in == $nu.os-info.name
      )

      if not $plat_supported {
        log info $"skipping ($x.src)"
      } else {
        let root = $x | get root? | default false

        let src = if $root {
          $config_path | path join ...$x.src
        } else {
          $config_path | path join config ...$x.src
        }
        let dest = $nu.home-dir | path join ...$x.dest

        log info $"linking ($src) to ($dest)"
        idempotent_symlink $src $dest
      }
    }

    symlink_local_bins

    # macos
    if (which komorebic | is-not-empty) {
       komorebic fetch-app-specific-configuration
    # windows and wsl w/ windows PATH appended to PATH
    } else if (which komorebic.exe | is-not-empty) {
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

    set_secrets_file

    fnm use lts-latest --install-if-missing

    # Disable XON/XOFF flow control so Ctrl+S reaches applications (e.g. Neovim)
    stty -ixon

    check-pinentry
}

def main [] {
  setup
}
