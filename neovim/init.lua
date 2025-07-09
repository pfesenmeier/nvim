---@diagnostic disable-next-line: undefined-global
local vim = vim

-- https://neovim.io/doc/user/lua.html#vim.loader
-- disabling because of lazy
-- vim.loader.enable()

vim.g.db = "postgres://postgres:password@localhost:5432/db"

require "config.lazy"

require "pfes.settings"
require "pfes.autocmds"
require "pfes.mappings"
require "pfes.rename"
require "pfes.local".setup()
require "pfes.keymap".setup()
require "tools".setup()

-- notes from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
