# brew dependencies on linux: build-essential

let tools = [
  gcc
  fzf
  fd
  carapace
  ripgrep
  difftastic
  fnm # used by homebrew script
  lua-language-server
  lua
  gh
  luarocks
  neovim
  nushell # not nu!
]

brew install ...$tools
