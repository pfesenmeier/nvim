# run winget install git.git --interactive
# run git clone https://github.com/pfesenmeier/nvim
# run winget install nushell.nushell
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# bootstrap new windows environment
def main [
  --all (-a) # install all tools
  --dev (-d) # install all general dev tools packages 
  --dotnet
] {

  if ([$all $dev] | all {|| $in == false}) {
    return (help main)
  }

  if ([$dev $all] | any {|| $in }) {
    for bucket in (get_buckets) {
       scoop bucket add $bucket
    }
    
    scoop install ...(get_tools)
    winget install --no-upgrade ...(get_utils)
  }

  # TODO - add in dotnet tools
  if $dotnet {
    winget install Microsoft.DotNet.SDK.8
  }

  print "run setup.nu with elevated permissions if have not already"
}

def get_buckets [] {
  [
    extras
    nerd-fonts
  ]
}

def get_utils [] {
  [
     "discord.discord"
     "google.chrome"
     "microsoft.visualstudiocode"
     "docker.dockerdesktop"
     "dbeaver.dbeaver"
     "GnuPG.Gpg4win" 
     "DevToys-app.DevToys"
     # firefox
     # linqpad
  ]
}


def get_tools [] {
  [ 
    neovim
    neovide
    vcredist2022 # needed for neovim
    nvm
    zig # used for treesitter

    starship
    "nerd-fonts/0xProto-NF-Mono"
  
    # cmdline
    ripgrep
    fd
    gsudo
    neovim
    gh
    fzf
    difftastic
    mdcat

    # building fzf-lua
    make
    gcc
  
    # neovim lsps
    marksman
    lua-language-server

    # tiling window managers
    komorebi 
    whkd

    # personal 
    deno
    rustup
  # a hack, since cmd may be different
  ] | where {|pkg| which $pkg | is-empty }
}

