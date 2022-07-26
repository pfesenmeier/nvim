local mappings = require "pfes/mappings"
local on_attach = mappings.on_attach;

-- Enable cmp with lsp servers.
local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())


require("lspconfig").rust_analyzer.setup{
    capabilities = capabilities,
    on_attach = on_attach,
    ['rust-analyzer'] = {
      settings = {
        cargo = {
         allFeatures = true,
      }
    },
  }
}

require("lspconfig").tsserver.setup{
  capabilities = capabilities,
  on_attach = on_attach
}
require('lspconfig').yamlls.setup{
  capabilities = capabilities,
  on_attach = on_attach
}

-- enabled via vscode-langservers-extracted
require("lspconfig").eslint.setup{
  capabilities = capabilities,
  on_attach = on_attach
}
require('lspconfig').html.setup{
  capabilities = capabilities,
  on_attach = on_attach
}
require('lspconfig').jsonls.setup{
  capabilities = capabilities,
  on_attach = on_attach
}
require('lspconfig').cssls.setup{
  capabilities = capabilities,
  on_attach = on_attach
}
require('lspconfig').tailwindcss.setup{
  capabilities = capabilities,
  on_attach = on_attach
}

require('lspconfig').bashls.setup{
  capabilities = capabilities,
  on_attach = on_attach
}

require'lspconfig'.sumneko_lua.setup {
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = {'vim'},
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
  capabilities = capabilities,
  on_attach = on_attach
}

