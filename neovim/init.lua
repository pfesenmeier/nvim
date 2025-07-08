---@diagnostic disable-next-line: undefined-global
local vim = vim

local env = require "pfes.env"

-- https://neovim.io/doc/user/lua.html#vim.loader
-- disabling because of lazy
-- vim.loader.enable()

vim.g.db = "postgres://postgres:password@localhost:5432/db"

require "config.lazy"

if env.islinux then
  require 'telescope'.load_extension('fzf')
end

require "pfes.settings"
require "pfes.autocmds"
require "pfes.mappings"
require "pfes.rename"
require "pfes.local".setup()
require "pfes.keymap".setup()

-- notes from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
