local packages = {
  -- "savq/paq-nvim";
  -- build :TSUpdate .. how not to run every time?
  { 'nvim-treesitter/nvim-treesitter', tag = 'v0.9.2' },
  { "nvim-treesitter/nvim-treesitter-textobjects" },
  "neovim/nvim-lspconfig",
  -- prevent remote code execution
  "ciaranm/securemodelines",

  -- debug
  { 'mfussenegger/nvim-dap', tag = '0.7.0' },
  'theHamsta/nvim-dap-virtual-text',

  "Pocco81/auto-save.nvim",
  -- testing
  'antoinemadec/FixCursorHold.nvim',
  { 'nvim-neotest/neotest', tag = 'v5.2.3' },
  { 'nvim-neotest/nvim-nio', tag = 'v1.9.3' },
  { 'Issafalcon/neotest-dotnet', tag = 'v1.5.3' },

  -- workspace defaults to closest .git 
  -- trying to use tcd (tab), lcd (window), cd
  "airblade/vim-rooter",

  "editorconfig/editorconfig-vim",

  -- database
  "tpope/vim-dadbod",
  "kristijanhusak/vim-dadbod-completion",

  -- workspace errors
  { "folke/trouble.nvim", tag = 'v2.10.0' },

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

if Env.islinux then
  -- depends on mingw on windows, which I never setup...
  table.insert(packages, { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' })
end

return packages
