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
  "nvim-treesitter/nvim-treesitter";
  "neovim/nvim-lspconfig";
}

require("lspconfig").rust_analyzer.setup{} 


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
