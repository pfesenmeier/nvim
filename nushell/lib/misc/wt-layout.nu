export def "wt layout" [] {
    let nu_bin = which nu | first | get path
    $env.window_config | items {|window_name, window_value|
      let dir = wslpath -w $window_value.dir
      wt.exe new-tab --title $window_name --tabColor $window_value.color -d $dir -- wsl.exe $nu_bin -e nvim
    }
}
