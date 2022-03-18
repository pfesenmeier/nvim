-- https://www.notonlycode.org/neovim-lua-config/
vim.g.mapleader = " "

local set_keymap = vim.api.nvim_set_keymap

set_keymap("n", "<leader>fg", ":Telescope live_grep<cr>", { noremap = true })
set_keymap("n", "<leader>ff", ":Telescope find_files<cr>", { noremap = true })
set_keymap("n", "<leader>fb", ":Telescope buffers<cr>", { noremap = true })
set_keymap("n", "<leader>fh", ":Telescope help_tags<cr>", { noremap = true })
set_keymap("n", "<leader>s", "<Plug>Sneak_s", { noremap = true })
set_keymap("n", "<leader>S", "<Plug>Sneak_S", { noremap = true })

