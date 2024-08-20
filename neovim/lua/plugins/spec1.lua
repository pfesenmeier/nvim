local packages = {
    {
        'nvim-treesitter/nvim-treesitter',
        build = ":TSUpdate",
        -- tag = 'v0.9.2',
        dependencies = "nvim-treesitter/nvim-treesitter-textobjects"
    },
    "neovim/nvim-lspconfig",
    -- prevent remote code execution
    { "ciaranm/securemodelines", lazy = true, event = "VeryLazy" },

    -- debug
    {
        'mfussenegger/nvim-dap',
        tag = '0.7.0',
        dependencies = { 'theHamsta/nvim-dap-virtual-text' }
    },

    { "Pocco81/auto-save.nvim",  lazy = true, event = "VeryLazy" },

    -- testing
    {
        'nvim-neotest/neotest',
        tag = 'v5.2.3',
        dependencies = {
            'antoinemadec/FixCursorHold.nvim',
            'nvim-neotest/nvim-nio',
            'Issafalcon/neotest-dotnet',
        }
    },
    { 'nvim-neotest/nvim-nio',         tag = 'v1.9.3' },
    { 'Issafalcon/neotest-dotnet',     tag = 'v1.5.3' },

    -- workspace defaults to closest .git
    -- trying to use tcd (tab), lcd (window), cd
    { "airblade/vim-rooter",           lazy = true,   event = "VeryLazy" },

    { "editorconfig/editorconfig-vim", lazy = true,   event = "VeryLazy" },

    -- database
    {
        "tpope/vim-dadbod",
        ft = "sql",
        lazy = false,
        dependencies = { "kristijanhusak/vim-dadbod-completion" }
    },

    -- workspace errors
    { "folke/trouble.nvim",   tag = 'v2.10.0' },

    -- fs
    { "lambdalisue/fern.vim", dependencies = { "lambdalisue/vim-fern-hijack", } },
    "tpope/vim-eunuch",

    -- completion
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-nvim-lua",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "hrsh7th/cmp-vsnip",
            "hrsh7th/vim-vsnip",
            "hrsh7th/cmp-nvim-lsp-signature-help",
        }
    },

    -- inspect decompiled C#
    { "Hoffs/omnisharp-extended-lsp.nvim", lazy = true, ft = "cs" },

    -- fuzzy search
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        }
    },

    -- git
    "lewis6991/gitsigns.nvim",
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
    "numToStr/Comment.nvim",

    'ellisonleao/gruvbox.nvim'
}

if Env.islinux then
    -- depends on mingw on windows, which I never setup...
    table.insert(packages, { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' })
end

return packages
