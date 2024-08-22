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

    -- format
    { "sbdchd/neoformat",        lazy = true, event = "VeryLazy" },

    { "Pocco81/auto-save.nvim",        enabled = false, lazy = true,       event = "VeryLazy" },

    -- workspace defaults to closest .git
    -- trying to use tcd (tab), lcd (window), cd
    { "airblade/vim-rooter",           lazy = true,     event = "VeryLazy" },

    { "editorconfig/editorconfig-vim", lazy = true,     event = "VeryLazy" },

    -- database
    {
        "tpope/vim-dadbod",
        ft = "sql",
        lazy = true,
        dependencies = { "kristijanhusak/vim-dadbod-completion" }
    },

    -- workspace errors
    { "folke/trouble.nvim",   tag = 'v2.10.0' },

    -- fs
    { "lambdalisue/fern.vim", dependencies = { "lambdalisue/vim-fern-hijack", }, priority = 999 },
    "tpope/vim-eunuch",

    -- inspect decompiled C#
    { "Hoffs/omnisharp-extended-lsp.nvim", lazy = true,    ft = "cs" },

    -- fuzzy search
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        }
    },

    -- git
    { "lewis6991/gitsigns.nvim", lazy = true, event = "VeryLazy" },

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

    { 'ellisonleao/gruvbox.nvim',          priority = 1000 }
}

if Env.islinux then
    -- depends on mingw on windows, which I never setup...
    table.insert(packages, { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' })
end

return packages
