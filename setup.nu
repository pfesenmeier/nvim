# may run with -n to skip loading on first run
use std log
use nushell/lib/misc/wsl.nu [is_wsl find_ms_home]

const self_path = path self

def set_secrets_file [] {
  let $env_file = $self_path | path dirname | path join nushell lib secrets.nu

  if ($env_file | path exists) {
    log info "env file already exists. skipping"

  } else {
    touch $env_file
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

def copy_wt_settings [ms_home: string, config_path: string] {
  if ($ms_home | is-empty) { return }

  let wt_dir = ls ($ms_home | path join "AppData/Local/Packages")
    | where name =~ 'Microsoft\.WindowsTerminal_'
    | where name !~ 'Preview'
    | get name
    | get 0?

  if ($wt_dir == null) { return }

  let src = $config_path | path join "config/windowsTerminalSettings.json"
  let dest = $wt_dir | path join "LocalState/settings.json"

  log info $"copying ($src) to ($dest)"
  cp --force $src $dest
}

# Builds a single elevated PowerShell call for all Windows symlinks so sudo prompts once.
# Requires Windows sudo enabled (Settings → System → For developers → Enable sudo).
def batch_windows_symlinks []: list<record<source: string, dest: string>> -> nothing {
  let pairs = $in
  if ($pairs | is-empty) { return }

  # wslpath -w fails on non-existent /mnt paths; convert those manually
  let to_win = {|p|
    if ($p | str starts-with '/mnt/') {
      $p | str replace --regex '^/mnt/([a-zA-Z])' '${1}:' | str replace --all '/' '\'
    } else {
      wslpath -w $p
    }
  }

  let win_pairs = $pairs | each {|pair| {
    source: $pair.source
    dest: $pair.dest
    win_source: (do $to_win $pair.source)
    win_dest: (do $to_win $pair.dest)
  }}

  for p in $win_pairs {
    log info $"linking ($p.source) to ($p.dest)"
  }

  let log_file = 'C:\Users\Public\symlink_setup_log.txt'

  let ps_commands = $win_pairs
    | each {|p| $"Remove-Item -Recurse -Force -ErrorAction SilentlyContinue '($p.win_dest)'; New-Item -ItemType SymbolicLink -Path '($p.win_dest)' -Target '($p.win_source)'"}
    | str join "; "

  let ps_wrapped = $"Start-Transcript -Path '($log_file)' -Force; try { ($ps_commands) } catch { Write-Error $_.Exception.Message }; Stop-Transcript"

  sudo.exe powershell.exe -NoProfile -Command $ps_wrapped

  let log_wsl = wslpath -u $log_file
  if ($log_wsl | path exists) { open $log_wsl | print }
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

      if $is_wsl and ($ms_home | is-not-empty) {
        let win_dest = $ms_home | path join ...$x.dest
        { source: $src, dest: $win_dest }
      }
    } | compact | batch_windows_symlinks

    # BUG settings is not portable (distribution guids)
    # TODO merge json documents 
    # if $is_wsl { copy_wt_settings $ms_home $config_path }

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
