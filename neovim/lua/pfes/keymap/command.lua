local M = {}
local opts = { noremap = true, silent = true }

M.setup = function()
  -- command line motions from :h cmdline.txt
  vim.keymap.set('c', '<C-A>', '<Home>', opts)
  vim.keymap.set('c', '<C-F>', '<Right>', opts)
  vim.keymap.set('c', '<C-B>', '<Left>', opts)

  -- <S-Right> ... the name for word motion
  vim.keymap.set('c', '<Esc>b', '<S-Left>', opts)
  vim.keymap.set('c', '<Esc>f', '<S-Right>', opts)
end

return M
