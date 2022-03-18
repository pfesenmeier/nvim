-- function nmap(shortcut, command)
--  vim.api.nvim_set_keymap('n', shortcut, command, { noremap = true, silent = true })
-- end
-- c('nnoremap <leader><leader> <c-^>')
--
-- TODO refactor?
-- cmd("nnoremap <Leader>T :lua require'lsp_extensions'.inlay_hints()")
-- nmap("<Leader>t", ":lua require'lsp_extensions'.inlay_hints{ enabled = {'TypeHint', 'ChainingHint', 'ParameterHint'}, ony_current_line = true }")
-- nmap('<Leader><Leader>', '<c-^>')
--
-- telescope shortcuts
vim.cmd("nnoremap <leader>ff :lua require'telescope.builtin'.find_files()<cr>");
vim.cmd("nnoremap <leader>fg <cmd>lua require('telescope.builtin').live_grep()<cr>");
vim.cmd("nnoremap <leader>fb <cmd>lua require('telescope.builtin').buffers()<cr>");
vim.cmd("nnoremap <leader>fh <cmd>lua require('telescope.builtin').help_tags()<cr>");

