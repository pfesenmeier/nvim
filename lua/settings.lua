local o = vim.opt
local c = vim.cmd

-- tabs are spaces
o.tabstop = 2 -- tabs are tabstop spaces long
o.shiftwidth = 2 -- indents are 2 widths long
o.softtabstop = 4 -- colunmn??
c('set expandtab') -- tabs are now spaces

-- theme stuff
c('syntax on')
vim.opt.termguicolors = true
vim.o.background = "dark"
c([[colorscheme gruvbox]])

-- papadark is installed
-- c('colorscheme papadark')
c('set number')
c('set relativenumber')
c('set nofoldenable')
-- <leader><leader> toggles between buffers
  
