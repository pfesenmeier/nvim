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
            local pid = vim.fn.getpid()

            local omnisharp_bin

            if Env.islinux then
                omnisharp_bin = Env.home .. "/.local/bin/OmniSharp/omnisharp-roslyn/OmniSharp"
            else
                -- omnisharp_bin = Env.home .. "/AppData/Local/OmniSharp/omnisharp-roslyn/OmniSharp.exe"
                omnisharp_bin = Env.home .. "/scoop/shims/omnisharp.exe"
            end

            opts.omnisharp.setup {

                handlers = {
                    ["textDocument/definition"] = require('omnisharp_extended').handler,
                },

                cmd = { omnisharp_bin, '--languageserver', '--hostPID', tostring(pid) },
                -- Enables support for reading code style, naming convention and analyzer
                -- settings from .editorconfig.
                enable_editorconfig_support = true,
                --
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
        end
    }
}
