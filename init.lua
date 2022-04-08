-- Paq Command: PaqSync

vim.g.mapleader = " "
-- to execute Vim commands 
local cmd = vim.cmd  
-- to call Vim functions
local fn = vim.fn    
-- a table to access global variables
local g = vim.g      
-- to set options
local opt = vim.opt 

-- install paq-nvim if not already installed ( from savq/paq-nvim )
local install_path = fn.stdpath('data') .. '/site/pack/paqs/start/paq-nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  fn.system({'git', 'clone', '--depth=1', 'https://github.com/savq/paq-nvim.git', install_path})
end

-- from https://oroques.dev/notes/neovim-init/
require "paq" {
  "savq/paq-nvim";
  -- 'simrat39/rust-tools.nvim'
  "nvim-treesitter/nvim-treesitter";
  "neovim/nvim-lspconfig";
  -- prevent remote code execution
  "ciaranm/securemodelines";

  -- jumping around
  'ggandor/lightspeed.nvim';

  -- workspace defaults to closest .git 
  "airblade/vim-rooter";

  -- inlay hints for Rust
  "nvim-lua/lsp_extensions.nvim";

  -- enable rust formatting
  "rust-lang/rust.vim";
  "editorconfig/editorconfig-vim";

  -- completion
  "hrsh7th/cmp-nvim-lsp";
  "hrsh7th/cmp-buffer";
  "hrsh7th/cmp-path";
  "hrsh7th/cmp-cmdline";
  "hrsh7th/nvim-cmp";
  "hrsh7th/cmp-vsnip";
  "hrsh7th/vim-vsnip";

  -- maybe rustdocs?
  "plasticboy/vim-markdown";

  -- colors
   "ellisonleao/gruvbox.nvim";

  -- fuzzy search
  "nvim-lua/plenary.nvim";
  "nvim-telescope/telescope.nvim";

  -- git
  "tpope/vim-fugitive";
  -- enable Gbrowse with github
  "tpope/vim-rhubarb";

  -- TODO vim surround again?
  -- TODO undo memory between settings
  -- TODO what is spell check?
}

require("pfes/lsp")
require("pfes/compare")
require("pfes/settings")
require("pfes/mappings")
require("pfes/treesitter")

-- notes from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
-- light line??
-- yank highliht
-- fzf - fuzzy search
-- undodir
-- set capslock to ctrl

