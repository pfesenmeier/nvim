require("lspconfig").rust_analyzer.setup{
  settings = {
    allFeatures = true,
  }
}

require("lspconfig").tsserver.setup{}
require('lspconfig').yamlls.setup{}

-- enabled via vscode-langservers-extracted
require("lspconfig").eslint.setup{}
require('lspconfig').html.setup{}
require('lspconfig').jsonls.setup{}
require('lspconfig').cssls.setup{}

