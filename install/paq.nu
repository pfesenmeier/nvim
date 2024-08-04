# from https://github.com/savq/paq-nvim
if ($nu.os-info.family == 'windows') {
    let install_path = $env.LOCALAPPDATA | path join nvim-data site pack paqs start paq-nvim

    if ($install_path | path exists) == false {
      git clone https://github.com/savq/paq-nvim.git $install_path
    }
} else {
    let install_path = [$nu.home-path .local share] | path join;
    if ($install_path | path exists) == false {
     git clone --depth=1 https://github.com/savq/paq-nvim.git $"($install_path)/nvim/site/pack/paqs/start/paq-nvim"
    }
}
