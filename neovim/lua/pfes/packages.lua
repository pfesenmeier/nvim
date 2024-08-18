local packages = {
  "savq/paq-nvim";
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate', branch = 'v0.9.2', pin = true },
  { "nvim-treesitter/nvim-treesitter-textobjects", pin = true },
  "neovim/nvim-lspconfig",
  -- prevent remote code execution
  "ciaranm/securemodelines",

  -- debug
  { 'mfussenegger/nvim-dap', branch = '0.7.0', pin = true },
  'theHamsta/nvim-dap-virtual-text',

  "Pocco81/auto-save.nvim",
  -- testing
  'antoinemadec/FixCursorHold.nvim',
  { 'nvim-neotest/neotest', branch = 'v5.2.3', pin = true },
  { 'nvim-neotest/nvim-nio', branch = 'v1.9.3', pin = true },
  { 'Issafalcon/neotest-dotnet', branch = 'v1.5.3', pin = true },

  -- workspace defaults to closest .git 
  -- trying to use tcd (tab), lcd (window), cd
  "airblade/vim-rooter",

  "editorconfig/editorconfig-vim",

  -- database
  "tpope/vim-dadbod",
  "kristijanhusak/vim-dadbod-completion",

  -- workspace errors
  { "folke/trouble.nvim", branch = 'v2.10.0', pin  = true },

  -- fs
  "lambdalisue/fern.vim",
  "lambdalisue/vim-fern-hijack",
  "tpope/vim-eunuch",

  -- completion 
  "hrsh7th/cmp-nvim-lsp",
  "hrsh7th/cmp-nvim-lua",
  "hrsh7th/cmp-buffer",
  "hrsh7th/cmp-path",
  "hrsh7th/cmp-cmdline",
  "hrsh7th/nvim-cmp",
  "hrsh7th/cmp-vsnip",
  "hrsh7th/vim-vsnip",
  "hrsh7th/cmp-nvim-lsp-signature-help",

  -- inspect decompiled C#
  "Hoffs/omnisharp-extended-lsp.nvim",

  -- fuzzy search
  "nvim-lua/plenary.nvim",
  "nvim-telescope/telescope.nvim",

  -- git
  "lewis6991/gitsigns.nvim",
  "tpope/vim-fugitive",
  -- enable Gbrowse
  "tpope/vim-rhubarb", -- with Github
  "cedarbaum/fugitive-azure-devops.vim", -- with ADO

  -- comments
  -- TODO comments now bundled with neovim
  "numToStr/Comment.nvim",

  'ellisonleao/gruvbox.nvim' 
}

return packages
