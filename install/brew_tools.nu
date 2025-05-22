# brew dependencies on linux: build-essential

let tools = [
  gcc
  fzf
  fd
  deno
  ripgrep
  difftastic
  fnm # used by homebrew script
  lua-language-server
  lua
  gh
  luarocks
  marksman
  neovim
  nushell # not nu!
  starship
]

brew install ...$tools
