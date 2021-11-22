function nmap(shortcut, command)
  vim.api.nvim_set_keymap('n', shortcut, command, { noremap = true, silent = true })
end
c('nnoremap <leader><leader> <c-^>')
--
-- TODO refactor?
-- cmd("nnoremap <Leader>T :lua require'lsp_extensions'.inlay_hints()")
nmap("<Leader>t", ":lua require'lsp_extensions'.inlay_hints{ enabled = {'TypeHint', 'ChainingHint', 'ParameterHint'}, ony_current_line = true }")
nmap('<Leader><Leader>', '<c-^>')
