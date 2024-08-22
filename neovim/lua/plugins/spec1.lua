local packages = {
    -- prevent remote code execution
    { "ciaranm/securemodelines",       lazy = true, event = "VeryLazy" },

    -- format
    {
        "sbdchd/neoformat",
        lazy = true,
        event = "VeryLazy"
    },

    {
        "Pocco81/auto-save.nvim",
        enabled = false,
        lazy = true,
        event = "VeryLazy"
    },

    -- workspace defaults to closest .git
    -- trying to use tcd (tab), lcd (window), cd
    {
        "airblade/vim-rooter",
        lazy = false,
        event = "UIEnter",
        init = function()
            vim.g.rooter_patterns = { '.git', 'Makefile', '*.sln', 'build/env.sh' }
        end
    },

    { "editorconfig/editorconfig-vim", lazy = true, event = "VeryLazy" },

    -- database
    {
        "tpope/vim-dadbod",
        ft = "sql",
        lazy = true,
        dependencies = { "kristijanhusak/vim-dadbod-completion" }
    },
    {
        'stevearc/dressing.nvim',
        opts = {},
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
            vim.keymap.set("n", "<leader>ow", function() require("trouble").toggle("workspace_diagnostics") end)
            vim.keymap.set("n", "<leader>od", function() require("trouble").toggle("document_diagnostics") end)
            vim.keymap.set("n", "<leader>oq", function() require("trouble").toggle("quickfix") end)
            vim.keymap.set("n", "<leader>ol", function() require("trouble").toggle("loclist") end)
            vim.keymap.set("n", "gR", function() require("trouble").toggle("lsp_references") end)
        end
    },

    -- fs
    { "lambdalisue/fern.vim",              dependencies = { "lambdalisue/vim-fern-hijack", }, priority = 999 },
    { "tpope/vim-eunuch",                  lazy = true,                                       event = "VeryLazy" },

    -- inspect decompiled C#
    { "Hoffs/omnisharp-extended-lsp.nvim", lazy = true,                                       ft = "cs" },

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
    { "lewis6991/gitsigns.nvim", opts = {}, lazy = true, event = "VeryLazy" },

    {
        "tpope/vim-fugitive",
        dependencies = {
            -- enable Gbrowse
            "tpope/vim-rhubarb",                   -- with Github
            "cedarbaum/fugitive-azure-devops.vim", -- with ADO
        }
    },

    -- comments
    -- TODO comments now bundled with neovim
    { "numToStr/Comment.nvim",   opts = {} },

    {
        'ellisonleao/gruvbox.nvim',
        priority = 1000,
        init = function()
            vim.cmd("colorscheme gruvbox")
        end,
        opts = {
            contrast = "hard", -- can be "hard", "soft" or empty string
            transparent_mode = true,
        }
    }
}

if Env.islinux then
    -- depends on mingw on windows, which I never setup...
    table.insert(packages, { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' })
end

return packages
