-- Enable cmp with lsp servers.
local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())

require("lspconfig").rust_analyzer.setup{
  ['rust-analyzer'] = {
    settings = {
      cargo = {
       allFeatures = true,
    }
  },
  capabilities = capabilities
}
}

require("lspconfig").tsserver.setup{
  capabilities = capabilities
}
require('lspconfig').yamlls.setup{
  capabilities = capabilities
}

-- enabled via vscode-langservers-extracted
require("lspconfig").eslint.setup{
  capabilities = capabilities
}
require('lspconfig').html.setup{
  capabilities = capabilities
}
require('lspconfig').jsonls.setup{
  capabilities = capabilities
}
require('lspconfig').cssls.setup{
  capabilities = capabilities
}


