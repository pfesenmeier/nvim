
local command = require('pfes.keymap.command')
local dap = require('pfes.keymap.dap')
local fs = require('pfes.keymap.fs')
local git = require('pfes.keymap.git')
local lsp = require('pfes.keymap.lsp')
local neotest = require('pfes.keymap.neotest')
local pick = require('pfes.keymap.pick')
local terminal = require('pfes.keymap.terminal')

local M = {}

function M.setup()
  command.setup()
  dap.setup()
  fs.setup()
  git.setup()
  lsp.setup()
  neotest.setup()
  pick.setup()
  terminal.setup()
end

return M
