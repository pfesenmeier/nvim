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

c('set number')
c('set nofoldenable')

-- set background transparent (I have background photo via Windows Terminal)
c('highlight Normal guibg=none')
c('highlight NonText guibg=none')

