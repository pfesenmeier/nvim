local mappings = require "pfes/mappings"
local on_attach = mappings.on_attach;

-- Enable cmp with lsp servers.
local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())


-- require("lspconfig").rust_analyzer.setup{
--     capabilities = capabilities,
--     on_attach = on_attach,
--     ['rust-analyzer'] = {
--       settings = {
--         cargo = {
--          allFeatures = true,
--       }
--     },
--   }
-- }

-- require("lspconfig").tsserver.setup{
--   capabilities = capabilities,
--   on_attach = on_attach
-- }
require('lspconfig').yamlls.setup{
  capabilities = capabilities,
  on_attach = on_attach
}

-- enabled via vscode-langservers-extracted
-- require("lspconfig").eslint.setup{
--   capabilities = capabilities,
--   on_attach = on_attach
-- }
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
-- require('lspconfig').tailwindcss.setup{
--   capabilities = capabilities,
--   on_attach = on_attach
-- }

-- require('lspconfig').bashls.setup{
--   capabilities = capabilities,
--   on_attach = on_attach
-- }

-- require('lspconfig').sqlls.setup{
--   capabilities = capabilities,
--   on_attach = on_attach
-- }

-- require'lspconfig'.lua_ls.setup {
--   on_init = function(client)
--     local path = client.workspace_folders[1].name
--     if not vim.loop.fs_stat(path..'/.luarc.json') and not vim.loop.fs_stat(path..'/.luarc.jsonc') then
--       client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
--         Lua = {
--           runtime = {
--             -- Tell the language server which version of Lua you're using
--             -- (most likely LuaJIT in the case of Neovim)
--             version = 'LuaJIT'
--           },
--           -- Make the server aware of Neovim runtime files
--           workspace = {
--             checkThirdParty = false,
--             library = {
--               vim.env.VIMRUNTIME
--               -- "${3rd}/luv/library"
--               -- "${3rd}/busted/library",
--             }
--             -- or pull in all of 'runtimepath'. NOTE: this is a lot slower
--             -- library = vim.api.nvim_get_runtime_file("", true)
--           }
--         }
--       })
--
--       client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
--     end
--     return true
--   end,
--   capabilities = capabilities,
--   on_attach = on_attach
-- }

-- OmniSharp Extended Setup
local pid = vim.fn.getpid()

-- On linux/darwin if using a release build, otherwise under scripts/OmniSharp(.Core)(.cmd)
-- local omnisharp_bin = "/path/to/omnisharp-repo/run"

-- on Windows
local omnisharp_bin = "/Program Files/omnisharp/bin/OmniSharp.exe"

require'lspconfig'.omnisharp.setup {

    handlers = {
      ["textDocument/definition"] = require('omnisharp_extended').handler,
    },

    cmd = { omnisharp_bin, '--languageserver' , '--hostPID', tostring(pid) },

    -- Enables support for reading code style, naming convention and analyzer
    -- settings from .editorconfig.
    enable_editorconfig_support = true,

    -- If true, MSBuild project system will only load projects for files that
    -- were opened in the editor. This setting is useful for big C# codebases
    -- and allows for faster initialization of code navigation features only
    -- for projects that are relevant to code that is being edited. With this
    -- setting enabled OmniSharp may load fewer projects and may thus display
    -- incomplete reference lists for symbols.
    enable_ms_build_load_projects_on_demand = false,

    -- Enables support for roslyn analyzers, code fixes and rulesets.
    enable_roslyn_analyzers = true,

    -- Specifies whether 'using' directives should be grouped and sorted during
    -- document formatting.
    organize_imports_on_format = true,

    -- Enables support for showing unimported types and unimported extension
    -- methods in completion lists. When committed, the appropriate using
    -- directive will be added at the top of the current file. This option can
    -- have a negative impact on initial completion responsiveness,
    -- particularly for the first few completion sessions after opening a
    -- solution.
    enable_import_completion = true,

    -- Specifies whether to include preview versions of the .NET SDK when
    -- determining which version to use for project loading.
    sdk_include_prereleases = true,

    -- Only run analyzers against open files when 'enableRoslynAnalyzers' is
    -- true
    analyze_open_documents_only = false,

    capabilities = capabilities,
    on_attach = on_attach
}
