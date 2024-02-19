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
  'antoinemadec/FixCursorHold.nvim';
  'nvim-neotest/neotest';
  'Issafalcon/neotest-dotnet';

  -- workspace defaults to closest .git 
  -- trying to use tcd (tab), lcd (window), cd
  "airblade/vim-rooter";

  "editorconfig/editorconfig-vim";

  -- database
  "tpope/vim-dadbod";
  "kristijanhusak/vim-dadbod-completion";

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

vim.g.dotnet_build_project = function()
    local default_path = vim.fn.getcwd() .. '/'
    if vim.g['dotnet_last_proj_path'] ~= nil then
        default_path = vim.g['dotnet_last_proj_path']
    end
    local path = vim.fn.input('Path to your *proj file ', default_path, 'file')
    vim.g['dotnet_last_proj_path'] = path
    local cmd = 'dotnet build -c Debug ' .. path 
    print('')
    print('Cmd to execute: ' .. cmd)
    local f = os.execute(cmd)
    if f == 0 then
        print('\nBuild: ✔️ ')
    else
        print('\nBuild: ❌ (code: ' .. f .. ')')
    end
end

-- https://github.com/mfussenegger/nvim-dap/wiki/Cookbook#making-debugging-net-easier
vim.g.dotnet_get_dll_path = function()
    local request = function()
        return vim.fn.input('Path to dll', vim.fn.getcwd(), 'file')
    end

    if vim.g['dotnet_last_dll_path'] == nil then
        vim.g['dotnet_last_dll_path'] = request()
    else
        if vim.fn.confirm('Do you want to change the path to dll?\n' .. vim.g['dotnet_last_dll_path'], '&yes\n&no', 2) == 1 then
            vim.g['dotnet_last_dll_path'] = request()
        end
    end

    return vim.g['dotnet_last_dll_path']
end

local config = {
  {
    type = "netcoredbg",
    name = "launch - netcoredbg",
    request = "launch",
    program = function()
        if vim.fn.confirm('Should I recompile first?', '&yes\n&no', 2) == 1 then
            vim.g.dotnet_build_project()
        end
        return vim.g.dotnet_get_dll_path()
    end,
  },
  {
    type = "netcoredbg",
    request = "attach",
    name = "attach - netcoredbg",
    processId = require('dap.utils').pick_process,
    args = {},
  },
}

-- if experiencing problems, make sure treesitter is up to date first!
dap.adapters.netcoredbg = {
  type = 'executable',
  command = home .. '\\AppData\\Local\\Samsung\\netcoredbg\\netcoredbg\\netcoredbg.exe',
  args = {'--interpreter=vscode'}
}

dap.configurations.cs = config
dap.configurations.fsharp = config

require("nvim-dap-virtual-text").setup()

require("neotest").setup({
  adapters = {
    require("neotest-dotnet")({
            discovery_root = "solution"
        })
  }
})

-- notes from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
