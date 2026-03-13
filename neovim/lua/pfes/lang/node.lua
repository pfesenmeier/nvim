local node = {}

node.addToLspConfig = function()
  vim.lsp.config('vtsls', {
    settings = {
      vtsls = {
        autoUseWorkspaceTsdk = true,
      },
    },
    filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact' },
  })
  vim.lsp.enable({ 'vtsls' })
end

return node
