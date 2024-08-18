# bootstrap new windows environment
def main [
  --all (-a) # install all tools
  --neovim (-n) # install neovim
  --scoop (-s) # install all scoop packages 
  --dotnet
] {

  if ([$all $neovim $scoop] | all {|| $in == false}) {
    return (help main)
  }

  if ([$scoop $all] | any {|| $in }) {
    scoop bucket add ...(get_buckets)
    scoop install ...(get_tools)
  }


  if ([$neovim $all] | any {|| $in }) {
    scoop install neovim
  }

  # TODO - add in dotnet tools
  if $dotnet {
    winget install Microsoft.DotNet.SDK.8
  }


  # use to install linux tools
  if (which git | is-empty) {
    winget install git.git --interactive
  }

  gsudo nu ($env.USERPROFILE | path join nvim setup.nu)
}

def get_buckets [] {
  [
    extras
    # nerd-fonts
  ]
}

def get_tools [] {
  [ 
    # utilties
    vcredist2022 # needed for alacritty
    nvm
    zig # used for treesitter
  
    # cmdline
    nu
    ripgrep
    fd
    eza
    gsudo
    neovim
    gh
    fzf
    difftastic
  
    # neovim lsps
    marksman
    lua-language-server
    # omnisharp
    # netcoredbg
     
    # gui
    alacritty
    # CascadiaCode-NF-Mono
    # firefox
    # linqpad
  
    # tiling window managers
    komorebi 
    whkd
  # a hack, since cmd may be different
  ] | where {|pkg| which $pkg | is-empty }
}

