local env = require "pfes.env"

local islinux = env.islinux

local packages = {
    -- prevent remote code execution
    { "ciaranm/securemodelines",       lazy = true, event = "VeryLazy" },
    {
        "Pocco81/auto-save.nvim",
        enabled = islinux,
        lazy = true,
        event = "VeryLazy",
        init = function()
            vim.api.nvim_set_keymap("n", "<leader>n", ":ASToggle<CR>", {})
        end
    },
    -- workspace defaults to closest .git
    -- trying to use tcd (tab), lcd (window), cd
    {
        "airblade/vim-rooter",
        lazy = false,
        event = "UIEnter",
        init = function()
            vim.g.rooter_patterns = { 'package.json', 'deno.json', '.git', 'Makefile', '*.sln',
                'build/env.sh' }
        end
    },
    { "editorconfig/editorconfig-vim", lazy = true, enabled = islinux, event = "VeryLazy" },
    -- database
    {
        "tpope/vim-dadbod",
        ft = "sql",
        lazy = true,
        enabled = islinux,
        dependencies = { "kristijanhusak/vim-dadbod-completion" }
    },
    -- workspace errors
    {
        "folke/trouble.nvim",
        enabled = false,
        tag = 'v2.10.0',
        opts = {
            -- settings without a patched font or icons
            icons = false,
            fold_open = "v",   -- icon used for open folds
            fold_closed = ">", -- icon used for closed folds
            -- indent_lines = true, -- add an indent guide below the fold icons
            signs = {
                -- icons / text used for a diagnostic
                error = "error",
                warning = "warn",
                hint = "hint",
                information = "info"
            },
            -- use_diagnostic_signs = true -- enabling this will use the signs defined in your lsp client
        },
        init = function()
            -- :h Trouble
            vim.keymap.set("n", "<leader>ox", function() require("trouble").toggle() end)
            vim.keymap.set("n", "<leader>ow",
                function() require("trouble").toggle("workspace_diagnostics") end)
            vim.keymap.set("n", "<leader>od",
                function() require("trouble").toggle("document_diagnostics") end)
            vim.keymap.set("n", "<leader>oq", function() require("trouble").toggle("quickfix") end)
            vim.keymap.set("n", "<leader>ol", function() require("trouble").toggle("loclist") end)
            vim.keymap.set("n", "gR", function() require("trouble").toggle("lsp_references") end)
        end
    },
    -- inspect decompiled C#
    {
        "Hoffs/omnisharp-extended-lsp.nvim",
        lazy = true,
        enabled = islinux,
        ft = "cs"
    },

    -- fuzzy search
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        opts = {
            -- ongoing issue: https://github.com/nvim-telescope/telescope.nvim/issues/2712
            defaults = {
                path_display = { "truncate" }
            }
        }

    },
    -- git
    {
        "lewis6991/gitsigns.nvim",
        opts = {
            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns

                local function map(mode, l, r, opts)
                    opts = opts or {}
                    opts.buffer = bufnr
                    vim.keymap.set(mode, l, r, opts)
                end

                -- Navigation
                map('n', ']c', function()
                    if vim.wo.diff then return ']c' end
                    vim.schedule(function() gs.next_hunk() end)
                    return '<Ignore>'
                end, { expr = true })

                map('n', '[c', function()
                    if vim.wo.diff then return '[c' end
                    vim.schedule(function() gs.prev_hunk() end)
                    return '<Ignore>'
                end, { expr = true })

                -- Actions
                map('n', '<leader>hs', gs.stage_hunk)
                map('n', '<leader>hr', gs.reset_hunk)
                map('v', '<leader>hs',
                    function() gs.stage_hunk { vim.fn.line('.'), vim.fn.line('v') } end)
                map('v', '<leader>hr',
                    function() gs.reset_hunk { vim.fn.line('.'), vim.fn.line('v') } end)
                map('n', '<leader>hS', gs.stage_buffer)
                map('n', '<leader>hu', gs.undo_stage_hunk)
                map('n', '<leader>hR', gs.reset_buffer)
                map('n', '<leader>hp', gs.preview_hunk)
                map('n', '<leader>hb', function() gs.blame_line { full = true } end)
                map('n', '<leader>tb', gs.toggle_current_line_blame)
                map('n', '<leader>hd', gs.diffthis)
                map('n', '<leader>hD', function() gs.diffthis('~') end)
                --    map('n', '<leader>td', gs.toggle_deleted)

                -- Text object
                map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
            end
        },
        enabled = islinux,
        tag = "v0.9.0",
        lazy = true,
        event = "VeryLazy"
    },

    {
        "tpope/vim-fugitive",
        lazy = true,
        event = "VeryLazy",
        dependencies = {
            -- enable Gbrowse
            "tpope/vim-rhubarb", -- with Github
            -- "cedarbaum/fugitive-azure-devops.vim", -- with ADO
        }
    },
    {
        "mhartington/formatter.nvim",
        enabled = islinux,
        config = function(_)
            require('formatter').setup {
                filetype = {
                    typescript = {
                        require("formatter.filetypes.typescript").prettier,
                    },
                }
            }

            local function prettier()
                local cwd = vim.uv.cwd()
                local dir = vim.fn.finddir('.git', '.;' .. env.home)

                vim.uv.chdir(dir .. '/..')
                print(vim.uv.cwd())
                vim.api.nvim_exec2("!git diff HEAD --name-only | xargs prettier -w", {})
                vim.uv.chdir(cwd)
            end

            vim.api.nvim_create_user_command("P", prettier, { bang = false })
        end,
        init = function()
            vim.keymap.set('n', '<leader><leader>f', ':Format<CR>')
        end
    },
    {
        'windwp/nvim-ts-autotag',
        opts = {},
    },
    {
        "zootedb0t/citruszest.nvim",
        lazy = false,
        init = function()
            vim.cmd("colorscheme citruszest")
        end,
        enabled = not islinux,
        priority = 1000,
    },
    {
        'ellisonleao/gruvbox.nvim',
        priority = 1000,
        enabled = islinux,
        init = function()
            vim.cmd("colorscheme gruvbox")
        end,
        opts = {
            contrast = "hard", -- can be "hard", "soft" or empty string
            transparent_mode = true,
        }
    }, { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make', enabled = islinux },
    {
        'stevearc/oil.nvim',
        opts = {
            default_file_explorer = islinux
        },
        lazy = true,
        event = "VeryLazy"
    },
    {
        "lambdalisue/fern.vim",
        enabled = not islinux,
        dependencies = {
            "lambdalisue/vim-fern-hijack",
            "yuki-yano/fern-preview.vim"
        },
        init = function()
            vim.cmd([[
                function! s:fern_settings() abort
                  nmap <silent> <buffer> p     <Plug>(fern-action-preview:toggle)
                  nmap <silent> <buffer> <C-p> <Plug>(fern-action-preview:auto:toggle)
                  nmap <silent> <buffer> <C-d> <Plug>(fern-action-preview:scroll:down:half)
                  nmap <silent> <buffer> <C-u> <Plug>(fern-action-preview:scroll:up:half)
                endfunction

                augroup fern-settings
                  autocmd!
                  autocmd FileType fern call s:fern_settings()
                augroup END
            ]]);
        end
    }
}

return packages
