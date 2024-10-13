local csharp = require "pfes.csharp"
local vue = require "pfes.vue"

return {
    {
        "neovim/nvim-lspconfig",
        lazy = true,
        -- currently will load when nvim-cmp loads cmp-nvim-lsp
        init = function()
            local opts = require "lspconfig"

            local function on_attach(_, bufnr)
                -- Enable completion triggered by <c-x><c-o>
                vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
                vim.lsp.inlay_hint.enable()

                -- Mappings.
                -- See `:help vim.lsp.*` for documentation on any of the below functions
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
                vim.keymap.set({ 'v', 'n' }, '<leader>ca', vim.lsp.buf.code_action, bufopts)
                vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)

                vim.keymap.set('n', '<leader>dt',
                    function()
                        vim.diagnostic.enable(not vim.diagnostic.is_enabled())
                    end, bufopts)
                vim.keymap.set('n', '<leader>f', function()
                    vim.lsp.buf.format { async = true }
                end, bufopts)
            end
            -- Enable cmp with lsp servers.
            local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())

            local lsps = {
                "rust_analyzer",

                -- enabled via vscode-langservers-extracted
                -- "html",
                -- "cssls",
                "jsonls",
                "eslint",

                "volar",
                "denols",
                "yamlls",
                "tailwindcss",
                "terraformls",

                "bashls",
                "nushell",
                "lua_ls",
                "sqlls",
                "marksman"
            }

            for _, value in ipairs(lsps) do
                opts[value].setup {
                    capabilities = capabilities,
                    on_attach = on_attach
                }
            end

            -- deno
            vim.g.markdown_fenced_languages = {
              "ts=typescript"
            }
            csharp.addToLspConfig(opts, capabilities, on_attach)
            -- removing ts_ls
            -- vue.addToLspConfig(opts, capabilities, on_attach)
        end
    }
}
