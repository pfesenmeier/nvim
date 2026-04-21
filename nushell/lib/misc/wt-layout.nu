use tmux-start.nu script_path

export def "wt layout" [] {
    $env.window_config | items {|window_name, window_value|
      let dir = wslpath -w $window_value.dir
      wt.exe new-tab --title $window_name --tabColor $window_value.color -d $dir -- wsl.exe $script_path $window_name $window_value.dir
    }
}
