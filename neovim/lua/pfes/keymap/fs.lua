local M = {}
local opts = { noremap = true, silent = true }

M.setup = function()
local function go_up()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == "" or string.match(bufname, "fugitive:") then
    vim.cmd('e .')
  elseif vim.o.buftype == "terminal" then
    vim.cmd('e .')
  else
    vim.cmd('e %:h')
  end
end
vim.keymap.set('n', '<leader>e', go_up, opts)

end

return M
