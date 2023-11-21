-- Paq Command: PaqSync

-- https://neovim.io/doc/user/lua.html#vim.loader
vim.loader.enable()

vim.g.mapleader = " "

-- install paq-nvim if not already installed ( from savq/paq-nvim )
-- commenting out... does not work on windows
-- local install_path = fn.stdpath('data') .. '/site/pack/paqs/start/paq-nvim'
-- if fn.empty(fn.glob(install_path)) > 0 then
  -- fn.system({'git', 'clone', '--depth=1', 'https://github.com/savq/paq-nvim.git', install_path})
-- end

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
  'antoinemadec/FixCursorHold.nvim';
  'nvim-neotest/neotest';
  'Issafalcon/neotest-dotnet';

  -- workspace defaults to closest .git 
  -- trying to use tcd (tab), lcd (window), cd
  "airblade/vim-rooter";

  "editorconfig/editorconfig-vim";

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

  -- git
  "lewis6991/gitsigns.nvim";
  "tpope/vim-fugitive";
  -- enable Gbrowse with github
  "tpope/vim-rhubarb";
  "cedarbaum/fugitive-azure-devops.vim";

  -- merges
  -- need to install https://github.com/Shougo/vimproc.vim: see windows binaries
  "Shougo/vimproc.vim";
  "idanarye/vim-merginal";

  -- comments
  "numToStr/Comment.nvim";
}

vim.g.rooter_patterns = {'.git', 'Makefile', '*.sln', 'build/env.sh'}

require("pfes/completion")
require("pfes/settings")
require("pfes/mappings")
require("pfes/treesitter")
require("pfes/lsp")

vim.cmd('au BufRead,BufNewFile *.nu		set filetype=nu')
require('Comment').setup()

require('gitsigns').setup()

local dap = require('dap')
local home = os.getenv('HOME')

dap.adapters.coreclr = {
  type = 'executable',
  command = home .. '\\AppData\\Local\\Samsung\\netcoredbg\\netcoredbg\\netcoredbg.exe',
  args = {'--interpreter=vscode'}
}

dap.adapters.netcoredbg = {
  type = 'executable',
  command = home .. '\\AppData\\Local\\Samsung\\netcoredbg\\netcoredbg\\netcoredbg.exe',
  args = {'--interpreter=vscode'}
}

dap.configurations.cs = {
  {
    type = "coreclr",
    request = "attach",
    name = "attach - netcoredbg",
    processId = require('dap.utils').pick_process,
    args = {},
  },
  {
    type = "coreclr",
    name = "launch - netcoredbg",
    request = "launch",
    program = function()
        return vim.fn.input('Path to dll', vim.fn.getcwd() .. '/bin/Debug/', 'file')
    end,
  },
}

require("nvim-dap-virtual-text").setup()

require("neotest").setup({
  adapters = {
    require("neotest-dotnet")
  }
})

-- notes from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
