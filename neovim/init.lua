-- Paq Command: PaqSync

-- hack to silence lsp warning
local vim = vim

Env = require"pfes/env"

-- https://neovim.io/doc/user/lua.html#vim.loader
vim.loader.enable()

vim.g.mapleader = " "
vim.g.db = "postgres://postgres:password@localhost:5432/db"

require("config.lazy")

require("auto-save").setup()

if Env.islinux then
  require('telescope').load_extension('fzf')
end

require("pfes/completion")
require("pfes/settings")
require("pfes/mappings")
require("pfes/treesitter")
require("pfes/lsp")
require("pfes/dap")

-- notes from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
