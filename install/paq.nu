# from https://github.com/savq/paq-nvim
if ($nu.os-info.family == 'windows') {
  # git clone https://github.com/savq/paq-nvim.git %LOCALAPPDATA%\nvim-data\site\pack\paqs\start\paq-nvim
  print 'TODO'
} else {
     let install_path = [$nu.home-path .local share] | path join;
     git clone --depth=1 https://github.com/savq/paq-nvim.git $"($install_path)/nvim/site/pack/paqs/start/paq-nvim"
}
