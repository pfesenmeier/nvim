vim.g.mapleader = " "
vim.g.netrw_browsex_viewer= "msedge.exe"

local o = vim.opt
local c = vim.cmd

-- tabs are spaces
o.tabstop = 2 -- tabs are tabstop spaces long
o.shiftwidth = 2 -- indents are 2 widths long
o.softtabstop = 4 -- colunmn??
o.scrolloff = 999 -- keep cursor in middle of screen
o.scrolloff = 999
o.expandtab = true

-- theme stuff
o.syntax = 'on'
o.termguicolors = true
o.background = "dark"
c([[colorscheme gruvbox]])

-- papadark is installed
-- c('colorscheme papadark')
c('set number')
c('set relativenumber')
c('set nofoldenable')
-- <leader><leader> toggles between buffers
  
-- better suggestions in terminal
-- TODO does not work o.wildmenu = true

-- TODO exclude public, node_modules from search results
