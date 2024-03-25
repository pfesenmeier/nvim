-- Paq Command: PaqSync

-- https://neovim.io/doc/user/lua.html#vim.loader
vim.loader.enable()

vim.g.mapleader = " "
vim.g.db = "postgres://postgres:password@localhost:5432/db"

-- from https://oroques.dev/notes/neovim-init/
require "paq" {
  "savq/paq-nvim";
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate' },
  "nvim-treesitter/nvim-treesitter-textobjects";
  "neovim/nvim-lspconfig";
  -- prevent remote code execution
  "ciaranm/securemodelines";

  -- debug
  'mfussenegger/nvim-dap';
  'theHamsta/nvim-dap-virtual-text';
  'rcarriga/nvim-dap-ui';
  'antoinemadec/FixCursorHold.nvim';
  'nvim-neotest/neotest';
  'nvim-neotest/nvim-nio';
  { 'Issafalcon/neotest-dotnet', branch = 'v1.5.3' },
  -- workspace defaults to closest .git 
  -- trying to use tcd (tab), lcd (window), cd
  "airblade/vim-rooter";

  "editorconfig/editorconfig-vim";

  -- database
  "tpope/vim-dadbod";
  "kristijanhusak/vim-dadbod-completion";

  -- workspace errors
  "folke/trouble.nvim";

  -- fs
  "lambdalisue/fern.vim";
  "tpope/vim-eunuch";
  -- "tpope/vim-vinegar";

  -- completion 
  "hrsh7th/cmp-nvim-lsp";
  "hrsh7th/cmp-nvim-lua";
  "hrsh7th/cmp-buffer";
  "hrsh7th/cmp-path";
  "hrsh7th/cmp-cmdline";
  "hrsh7th/nvim-cmp";
  "hrsh7th/cmp-vsnip";
  "hrsh7th/vim-vsnip";
  "hrsh7th/cmp-nvim-lsp-signature-help";

  -- inspect decompiled C#
  "Hoffs/omnisharp-extended-lsp.nvim";

  -- colors
   "ellisonleao/gruvbox.nvim";

  -- fuzzy search
  "nvim-lua/plenary.nvim";
  "nvim-telescope/telescope.nvim";
  { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },

  -- git
  "lewis6991/gitsigns.nvim";
  "tpope/vim-fugitive";
  -- enable Gbrowse with github
  "tpope/vim-rhubarb";
  "cedarbaum/fugitive-azure-devops.vim";

  -- merges
  -- need to install https://github.com/Shougo/vimproc.vim: see windows binaries
  -- "Shougo/vimproc.vim";
  -- "idanarye/vim-merginal";

  -- comments
  "numToStr/Comment.nvim";
}

vim.g.rooter_patterns = {'.git', 'Makefile', '*.sln', 'build/env.sh'}

require("pfes/completion")
require("pfes/settings")
require("pfes/mappings")
require("pfes/treesitter")
require("pfes/lsp")
require("pfes/dap")

vim.cmd('au BufRead,BufNewFile *.nu		set filetype=nu')
require('Comment').setup()

require('gitsigns').setup()

require("trouble").setup({
-- settings without a patched font or icons
    icons = false,
    fold_open = "v", -- icon used for open folds
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
})

-- notes from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
