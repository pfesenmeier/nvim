const path_self = path self

# copy networking folders. requires sudo priveledges
# sudo /home/linuxbrew/.linuxbrew/bin/nu ./scripts/wsl_setup.nu
def main [] {
  let config_dir = $path_self | path dirname -n 2 | path join config

  [resolv.conf wsl.conf] | each {|conf|
     let src = $config_dir | path join $conf
     let dest = '/etc/' | path join $conf
     print $"copying ($src) to ($dest)"

     sudo cp -f $src $dest
  }

  # lock the file so systemd does not overwrite it
  sudo chattr +i /etc/resolv.conf
}
