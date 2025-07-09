local M = {}
local env = require('pfes.env')
local opts = { noremap = true, silent = true }

local pick = function()
  return require('mini.pick')
end

function M.setup()
  vim.keymap.set("n", "<leader>j",
    function() return pick().builtin.files() end, opts)
  vim.keymap.set("n", "<leader>J",
    function() return pick().builtin.files(nil, { source = { cwd = env.home } }) end, opts)
  vim.keymap.set("n", "<leader>k",
    function() return pick().builtin.grep_live() end, opts)
  vim.keymap.set("n", "<leader>K",
    function() return pick().builtin.grep_live(nil, { source = { cwd = env.home } }) end, opts)

  vim.keymap.set("n", "<leader>b", function() return pick().builtin.buffers() end, opts)
  vim.keymap.set("n", "<leader>h", function() return pick().builtin.help() end, opts)

  vim.keymap.set("n", "<leader>rr", function() return pick().builtin.resume() end, opts)
end

return M
