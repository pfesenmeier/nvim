# may run with -n to skip loading on first run
use std/log

const self_path = path self

def check-pinentry [] {
  if $nu.os-info.name == "linux" and (which pinentry-gnome3 | is-empty) {
    log warning "pinentry-gnome3 is not installed on this system"
    log warning "install with 'sudo apt install pinentry-gnome3 dbus-x11 pass'"
    log warning "then run scripts/gpg_setup.nu"
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
  # ls instead of glob: on windows the backslashes in the path
  # are treated as escape characters in the glob pattern
  let srcs = ls $srcs | get name
  # .cmd wrappers are only for windows
  let srcs = if $nu.os-info.family == 'windows' {
    $srcs
  } else {
    $srcs | where {|src| ($src | path parse | get extension) != 'cmd' }
  }

  let dest_dir = $nu.home-dir | path join .local bin

  $srcs | each {|src|
    let dest = $src | path basename
    let dest = $dest_dir | path join $dest

    log info $"linking ($src) to ($dest)"
    idempotent_symlink $src $dest
  }
}

# programs not started from nushell (e.g. claude hooks) need ~/.local/bin on the windows user PATH
def add_local_bin_to_windows_path [] {
  if $nu.os-info.family != 'windows' { return }

  let local_bin = $nu.home-dir | path join .local bin
  let user_path = powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('PATH','User')" | str trim

  if ($user_path | split row ';' | any {|p| $p == $local_bin }) {
    log info $"($local_bin) already on user PATH"
  } else {
    log info $"adding ($local_bin) to user PATH"
    let cmd = "[Environment]::SetEnvironmentVariable('PATH', '" + $local_bin + ";' + [Environment]::GetEnvironmentVariable('PATH','User'), 'User')"
    powershell -NoProfile -Command $cmd
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

  # --no-symlink: also catch existing links, including broken ones,
  # which plain `path exists` reports as missing because it follows the link
  if ($dest | path exists --no-symlink) {
    log info $"removing existing ($dest)"
    rm --recursive --permanent $dest
  }

  symlink $source $dest
}

def idempotent_copy [source: string, dest: string] {
  let dest_dir = $dest | path dirname
  mkdir $dest_dir

  if ($dest | path exists --no-symlink) {
    log info $"removing existing ($dest)"
    rm --recursive --permanent $dest
  }

  cp --recursive $source $dest
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

  let herdr_core_config_folder = (
    (if $nu.os-info.family == 'windows' { [AppData Roaming] } else { [.config] })
    | append herdr-core
  )

  # native jj on windows ignores ~/.config/jj
  let jj_config_folder = (
    (if $nu.os-info.family == 'windows' { [AppData Roaming] } else { [.config] })
    | append jj
  )

  let neovide_config_folder = (
    (if $nu.os-info.family == 'windows' { [AppData Roaming] } else { [.config] })
    | append neovide
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
      src: [claude themes]
      dest: [.claude themes]
    } {
      src: [jjui]
      dest: [.config jjui]
    } {
      # the scoop jjui package sets JJUI_CONFIG_DIR to this folder, so jjui ignores ~/.config/jjui
      src: [jjui]
      dest: [scoop persist jjui config]
      plat: windows
    } {
      src: [jj config.toml]
      dest: ($jj_config_folder | append config.toml)
    } {
      # herdr-app owns the rest of its home folder, so only link my own mods and layouts
      src: [herdr-app mods my-new-menu]
      dest: [.config herdr-app mods my-new-menu]
    } {
      src: [herdr-app mods my-tabs]
      dest: [.config herdr-app mods my-tabs]
    } {
      src: [herdr-app mods my-prs]
      dest: [.config herdr-app mods my-prs]
    } {
      src: [herdr-app layouts my-main.json]
      dest: [.config herdr-app layouts my-main.json]
    } {
      src: [herdr-app themes everforest-light.json]
      dest: [.config herdr-app themes everforest-light.json]
    } {
      # herdr won't load images that resolve outside its home folder, so copy instead of link
      src: [herdr-app my-icons]
      dest: [.config herdr-app my-icons]
      copy: true
    } {
      src: [herdr-app programs.json]
      dest: [.config herdr-app programs.json]
    } {
      src: [herdr-core config.toml]
      dest: ($herdr_core_config_folder | append config.toml)
    } {
      src: [neovide config.toml]
      dest: ($neovide_config_folder | append config.toml)
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

        if ($x | get copy? | default false) {
          log info $"copying ($src) to ($dest)"
          idempotent_copy $src $dest
        } else {
          log info $"linking ($src) to ($dest)"
          idempotent_symlink $src $dest
        }
      }
    }

    symlink_local_bins
    add_local_bin_to_windows_path

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

    pnpm runtime set node lts -g

    # Disable XON/XOFF flow control so Ctrl+S reaches applications (e.g. Neovim)
    # (windows has no stty and no XON/XOFF to disable)
    if $nu.os-info.family != 'windows' {
      stty -ixon
    }

    check-pinentry
}

def main [] {
  setup
}
