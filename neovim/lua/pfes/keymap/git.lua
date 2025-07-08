local M = {}
local opts = { noremap = true, silent = true }

M.setup = function()
vim.keymap.set({ "n", "v" }, "gn", function()
  require('gitsigns').next_hunk()
end, opts)

end

return M
