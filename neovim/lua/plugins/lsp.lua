return {
    {
        "neovim/nvim-lspconfig",
        lazy = true,
        -- currently will load when nvim-cmp loads cmp-nvim-lsp
        config = function()
            local opts = require "lspconfig"

            -- Use an on_attach function to only map the following keys
            -- after the language server attaches to the current buffer
            -- see lsp.lua where this is being used
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
                -- "eslint",

                -- "tsserver",
                "yamlls",
                -- "tailwindcss",

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

            -- OmniSharp Extended Setup
            -- local pid = vim.fn.getpid()

            local omnisharp_dll

            if Env.islinux then
                omnisharp_dll = Env.home .. "/.local/bin/OmniSharp/omnisharp-roslyn/OmniSharp.dll"
            else
                omnisharp_dll = Env.home .. "/AppData/Local/OmniSharp/omnisharp-roslyn/OmniSharp.dll"
            end

            opts.omnisharp.setup {

                handlers = {
                    ["textDocument/definition"] = require('omnisharp_extended').handler,
                },
               -- cmd = { omnisharp_bin, '--languageserver', '--hostPID', tostring(pid) },
                cmd = { "dotnet", omnisharp_dll },

                settings = {
                    FormattingOptions = {
                        -- Enables support for reading code style, naming convention and analyzer
                        -- settings from .editorconfig.
                        EnableEditorConfigSupport = true,
                        -- Specifies whether 'using' directives should be grouped and sorted during
                        -- document formatting.
                        OrganizeImports = true,
                    },
                    MsBuild = {
                        -- If true, MSBuild project system will only load projects for files that
                        -- were opened in the editor. This setting is useful for big C# codebases
                        -- and allows for faster initialization of code navigation features only
                        -- for projects that are relevant to code that is being edited. With this
                        -- setting enabled OmniSharp may load fewer projects and may thus display
                        -- incomplete reference lists for symbols.
                        LoadProjectsOnDemand = nil,
                    },
                    RoslynExtensionsOptions = {
                        -- Enables support for roslyn analyzers, code fixes and rulesets.
                        EnableAnalyzersSupport = true,
                        -- Enables support for showing unimported types and unimported extension
                        -- methods in completion lists. When committed, the appropriate using
                        -- directive will be added at the top of the current file. This option can
                        -- have a negative impact on initial completion responsiveness,
                        -- particularly for the first few completion sessions after opening a
                        -- solution.
                        EnableImportCompletion = true,
                        -- Only run analyzers against open files when 'enableRoslynAnalyzers' is
                        -- true
                        AnalyzeOpenDocumentsOnly = nil,
                    },
                    Sdk = {
                        -- Specifies whether to include preview versions of the .NET SDK when
                        -- determining which version to use for project loading.
                        IncludePrereleases = true,
                    },
                },

                capabilities = capabilities,
                on_attach = on_attach
            }
        end
    }
}
