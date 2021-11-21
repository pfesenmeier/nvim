-- Paq Command: PaqSync
local cmd = vim.cmd  -- to execute Vim commands e.g. cmd('pwd')
local fn = vim.fn    -- to call Vim functions e.g. fn.bufnr()
local g = vim.g      -- a table to access global variables
local opt = vim.opt  -- to set options

-- install paq-nvim if not already installed
-- from https://github.com/savq/paq-nvim
local install_path = fn.stdpath('data') .. '/site/pack/paqs/start/paq-nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  fn.system({'git', 'clone', '--depth=1', 'https://github.com/savq/paq-nvim.git', install_path})
end

-- from https://oroques.dev/notes/neovim-init/
require "paq" {
  "savq/paq-nvim";
  -- once 0.6 hits
  -- "nvim-treesitter/nvim-treesitter";
  "neovim/nvim-lspconfig";
  -- prevent remote code execution
  "ciaranm/securemodelines";
  -- "editorconfig/editorconfig-vim";
  -- "justinmk/vim-sneak";
  "airblade/vim-rooter";
  -- on instead, telescope.vim?
  -- "junegunn/fzf";
  -- "junegunn/fzf.vim";
  --  "hrsh7th/nvim-cmp";
  "nvim-lua/lsp_extensions.nvim";
  -- enable rust formatting
  "rust-lang/rust.vim";

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
   "rktjmp/lush.nvim";
   "MordechaiHadad/nvim-papadark";
}

vim.cmd('syntax on')
vim.cmd('set termguicolors')
vim.cmd('colorscheme papadark')

require("lspconfig").rust_analyzer.setup{
  settings = {
    allFeatures = true,
  }
}

-- TODO refactor?
-- cmd("nnoremap <Leader>T :lua require'lsp_extensions'.inlay_hints()")
vim.api.nvim_set_keymap('n', "<Leader>t", ":lua require'lsp_extensions'.inlay_hints{ enabled = {'TypeHint', 'ChainingHint', 'ParameterHint'}, ony_current_line = true }", { noremap = true, silent = true })

-- autocomplete setup
cmd('set completeopt=menu,menuone,noselect')

-- TODO put in other file, automate copying over...
-- or just override where this file is supposed to be?
local cmp = require'cmp'

cmp.setup({
  snippet = {
    -- REQUIRED - you must specify a snippet engine
    expand = function(args)
      vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
      -- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
      -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
      -- require'snippy'.expand_snippet(args.body) -- For `snippy` users.
    end,
  },
  mapping = {
    ['<C-b>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
    ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
    ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
    ['<C-y>'] = cmp.config.disable, -- Specify `cmp.config.disable` if you want to remove the default `<C-y>` mapping.
    ['<C-e>'] = cmp.mapping({
      i = cmp.mapping.abort(),
      c = cmp.mapping.close(),
    }),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  },
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    -- { name = 'luasnip' }, -- For luasnip users.
    -- { name = 'ultisnips' }, -- For ultisnips users.
    -- { name = 'snippy' }, -- For snippy users.
  }, {
    { name = 'buffer' },
  })
})

-- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline('/', {
  sources = {
    { name = 'buffer' }
  }
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(':', {
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    { name = 'cmdline' }
  })
})

-- Setup lspconfig.
local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
-- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
require('lspconfig')['rust_analyzer'].setup {
  capabilities = capabilities
}

-- tabs are spaces
opt.tabstop = 2 -- tabs are tabstop spaces long
opt.shiftwidth = 2 -- indents are 2 widths long
opt.softtabstop = 4 -- colunmn??
cmd('set expandtab') -- tabs are now spaces



-- notes from https://github.com/jonhoo/configs/blob/master/editor/.config/nvim/init.vim
-- https://www.youtube.com/watch?v=ycMiMDHopNc&t=3791s
-- plugged 
-- nvim +PlugIntall +PlugClean
-- light line??
-- ale for.... no matter
-- yank highliht
-- vim rooter
-- fzf - fuzzy search
-- leader character 'space', 'space' 'space' to switch to file I was just in 
-- Language Client?? - do not need it , ound
-- ncm - autocomplete
-- undodir
-- set capslock to ctrl
-- remmeber you are using dvorak
-- 
