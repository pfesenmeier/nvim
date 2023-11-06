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
  -- 'simrat39/rust-tools.nvim'
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate' },
  "neovim/nvim-lspconfig";
  -- prevent remote code execution
  "ciaranm/securemodelines";

  -- jumping around
  'ggandor/lightspeed.nvim';

  -- debug
  'mfussenegger/nvim-dap';
  'theHamsta/nvim-dap-virtual-text';

  -- workspace defaults to closest .git 
  -- removing for now to work in current project
  "airblade/vim-rooter";

  -- inlay hints for Rust
  "nvim-lua/lsp_extensions.nvim";

  -- enable rust formatting
  "rust-lang/rust.vim";
  "editorconfig/editorconfig-vim";

  -- completion
  "hrsh7th/cmp-nvim-lsp";
  "hrsh7th/cmp-nvim-lua";
  "hrsh7th/cmp-buffer";
  "FelipeLema/cmp-async-path";
  -- "hrsh7th/cmp-path";
  "hrsh7th/cmp-cmdline";
  "hrsh7th/nvim-cmp";
  "hrsh7th/cmp-vsnip";
  "hrsh7th/vim-vsnip";

  -- inspect decompiled C#
  "Hoffs/omnisharp-extended-lsp.nvim";

  -- maybe rustdocs?
  "plasticboy/vim-markdown";

  -- colors
   "ellisonleao/gruvbox.nvim";

  -- autosave
  "pocco81/auto-save.nvim";

  -- fuzzy search
  "nvim-lua/plenary.nvim";
  "nvim-telescope/telescope.nvim";

  -- file explorer
  "nvim-telescope/telescope-file-browser.nvim";

  -- git
  "tpope/vim-fugitive";
  -- enable Gbrowse with github
  "tpope/vim-rhubarb";

  -- comments
  "numToStr/Comment.nvim";

  -- make missing directories on save
  "jghauser/mkdir.nvim";

  -- TODO vim surround again?
  -- TODO undo memory between settings
  -- TODO what is spell check?
}

vim.g.rooter_patterns = {'.git', 'Makefile', '*.sln', '*.csproj', 'build/env.sh'}

require("pfes/completion")
require("pfes/settings")
require("pfes/mappings")
require("pfes/treesitter")
require("pfes/lsp")

vim.cmd('au BufRead,BufNewFile *.nu		set filetype=nu')
require('Comment').setup()

require("telescope").setup {
  extensions = {
    file_browser = {
      theme = "ivy",
      -- disables netrw and use telescope-file-browser in its place
      hijack_netrw = true,
    },
  },
}

require("telescope").load_extension "file_browser"

local dap = require('dap')

dap.adapters.coreclr = {
  type = 'executable',
  command = 'C:\\Users\\pfese\\AppData\\Local\\Samsung\\netcoredbg\\netcoredbg\\netcoredbg.exe',
  args = {'--interpreter=vscode'}
}

dap.configurations.cs = {
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

-- notes from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
-- light line??
-- yank highliht
-- undodir
-- set capslock to ctrl
