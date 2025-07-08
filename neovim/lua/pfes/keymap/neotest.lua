local M = {}
local opts = { noremap = true, silent = true }

local function neotest(runArgs)
  require("neotest").run.run(runArgs)
  vim.notify("tests have begun")
end

M.setup = function()
  vim.keymap.set('n', '<leader>tr', function() return neotest() end, { noremap = true })
  vim.keymap.set('n', '<leader>tf', function() return neotest(vim.fn.expand("%")) end, { noremap = true })
  vim.keymap.set('n', '<leader>td', function() return neotest({ strategy = "dap" }) end, { noremap = true })
  vim.keymap.set('n', '<leader>tt', function()
    require('neotest').summary.toggle()
  end, opts)
  vim.keymap.set('n', '<leader>to', function()
    require('neotest').summary.open()
    vim.cmd(':wincmd l', opts)
  end, opts)
  vim.keymap.set('n', '<leader>tc', function()
    require('neotest').summary.close()
  end, opts)
end

return M
