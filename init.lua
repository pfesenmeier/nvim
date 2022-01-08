-- Paq Command: PaqSync
local cmd = vim.cmd  -- to execute Vim commands e.g. cmd('pwd')
local fn = vim.fn    -- to call Vim functions e.g. fn.bufnr()
local g = vim.g      -- a table to access global variables
local opt = vim.opt  -- to set options

-- install paq-nvim if not already installed ( from savq/paq-nvim )
local install_path = fn.stdpath('data') .. '/site/pack/paqs/start/paq-nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  fn.system({'git', 'clone', '--depth=1', 'https://github.com/savq/paq-nvim.git', install_path})
end

-- from https://oroques.dev/notes/neovim-init/
require "paq" {
  "savq/paq-nvim";
  -- once 0.6 hits
  "nvim-treesitter/nvim-treesitter";
  --TODO - does not work
  -- {"nvim-treesitter/nvim-treesitter", do = "TSUpdate" };
  "neovim/nvim-lspconfig";
  -- prevent remote code execution
  "ciaranm/securemodelines";
  -- "justinmk/vim-sneak";
  -- keep off while working on aoc
  "airblade/vim-rooter";
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
  -- TODO better colors?
   "rktjmp/lush.nvim";
   "MordechaiHadad/nvim-papadark";

  -- fuzzy search
  -- TODO install telescope
  {"nvim-telescope/telescope-fzf-native.nvim", run = "make" };
}

require("rust_analyzer")
require("compare")
require("settings")
require("mappings")
require("treesitter")

-- notes from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
-- light line??
-- yank highliht
-- fzf - fuzzy search
-- undodir
-- set capslock to ctrl

