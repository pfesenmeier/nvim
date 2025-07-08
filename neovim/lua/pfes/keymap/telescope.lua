local M = {}
local env = require('pfes.env')
local opts = { noremap = true, silent = true }

local telescope = function()
  return require('telescope.builtin')
end

function M.set()
  vim.keymap.set("n", "<leader>j",
    function() return telescope().find_files({ path_display = { "truncate" } }) end, opts)
  vim.keymap.set("n", "<leader>J",
    function() return telescope().find_files({ cwd = env.home, path_display = { "truncate" } }) end,
    opts)
  vim.keymap.set("n", "<leader>k",
    function() return telescope().live_grep({ path_display = { "truncate" } }) end, opts)
  vim.keymap.set("n", "<leader>K",
    function() return telescope().live_grep({ cwd = env.home, path_display = { "truncate" } }) end, opts)

  vim.keymap.set("n", "<leader>s", function() return telescope().lsp_document_symbols() end, opts)
  vim.keymap.set("n", "<leader>S", function() return telescope().lsp_workspace_symbols() end, opts)

  vim.keymap.set("n", "<leader>b", function() return telescope().buffers() end, opts)
  vim.keymap.set("n", "<leader>h", function() return telescope().help_tags() end, opts)
  vim.keymap.set("n", "<leader>ft", function() return telescope().treesitter() end, opts)
  vim.keymap.set("n", "<leader>fe", function() return telescope().diagnostics() end, opts)
  vim.keymap.set("n", "<leader>fg", function() return telescope().git_branches() end, opts)
  vim.keymap.set("n", "<leader>fc", function() return telescope().git_bcommits() end, opts)
  vim.keymap.set("n", "<leader>rr", function() return telescope().resume() end, opts)
end

return M
