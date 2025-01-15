# brew dependencies on linux: build-essential

let tools = [
  gcc
  fzf
  fd
  carapace
  ripgrep
  fnm # used by homebrew script
  lua-language-server
  lua
  gh
  luarocks
  neovim
  nushell # not nu!
]

brew install ...$tools
