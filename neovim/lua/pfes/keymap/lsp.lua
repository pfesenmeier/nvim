local M = {}
local opts = { noremap = true, silent = true }

M.setup = function()
  vim.keymap.set('n', 'gE', function() return vim.diagnostic.jump { count = -1, severity = "ERROR", float = true } end,
    opts)
  vim.keymap.set('n', 'ge', function() return vim.diagnostic.jump { count = 1, severity = "ERROR", float = true } end,
    opts)
  vim.keymap.set('n', 'gW', function() return vim.diagnostic.jump { count = -1, float = true } end, opts)
  vim.keymap.set('n', 'gw', function() return vim.diagnostic.jump { count = 1, float = true } end, opts)
end

function M.set(bufnr)
  local bufopts = { buffer = bufnr }
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
  vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, bufopts)
  vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
  vim.keymap.set('n', '<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, bufopts)
  vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, bufopts)
  vim.keymap.set({ 'v', 'n' }, '<leader>.', vim.lsp.buf.code_action, bufopts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)

  vim.keymap.set('n', '<leader>dt',
    function()
      vim.diagnostic.enable(not vim.diagnostic.is_enabled())
    end, bufopts)
  vim.keymap.set('n', '<leader>f', function()
    vim.lsp.buf.format { async = true }
  end, bufopts)
end

return M
