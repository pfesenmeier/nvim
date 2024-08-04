let tools = [ 
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

let buckets = [
  extras
  # nerd-fonts
]

# use to install linux tools
if (which git | is-empty) {
  winget install git.git --interactive
}

scoop bucket add ...$buckets
scoop install ...$tools

nu ($env.FILE_PWD | path join paq.nu)
gsudo nu ($env.USERPROFILE | path join nvim setup.nu)

nvim --headless -u NONE -c 'lua require("bootstrap").headless_paq()'
