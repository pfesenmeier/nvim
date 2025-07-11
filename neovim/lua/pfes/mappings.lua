

local opts = { noremap = true, silent = true }

vim.keymap.set("n", "<leader>g", ":tab :G<CR>", { noremap = true, silent = true })

-- leader maps below homerow on left hand for DVORAK
vim.keymap.set("n", "<leader>x", ":x<cr>", { noremap = true })

-- paste over something in visual mode without changing buffer
vim.keymap.set("x", "<leader>p", "\"_dP", opts)

-- switch buffers
vim.keymap.set("n", "<left>", ":bp<cr>", opts)
vim.keymap.set("n", "<right>", ":bn<cr>", opts)

-- move to ends of lines with homerow
vim.keymap.set("n", "H", "^", opts)
vim.keymap.set("n", "L", "$", opts)

vim.keymap.set('n', '<A-l>', ':cnext<cr>')
vim.keymap.set('n', '<A-h>', ':cprev<cr>')

vim.cmd('hi MiniPickMatchCurrent guibg=#458588')
vim.cmd('hi MiniPickMatchMarked guibg=#504945')
