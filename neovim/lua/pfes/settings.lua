vim.g.netrw_browsex_viewer= "msedge.exe"
vim.g.netrw_banner=0

local o = vim.opt
local c = vim.cmd

-- set windows clipboard
c('set clipboard=unnamedplus')

-- tabs are spaces
o.tabstop = 2 -- tabs are tabstop spaces long
o.shiftwidth = 2 -- indents are 4 widths long
o.softtabstop = 2 -- colunmn??
o.scrolloff = 999 -- keep cursor in middle of screen
o.expandtab = true

c('set noshellslash')

-- default highlight group for nvim-dap is a bright blue
vim.api.nvim_set_hl(0, 'debugPC', { bg = '#341F36' })

c('set relativenumber')
c('set nofoldenable')
c('set nofixendofline') 

-- add <> for % motion
-- see :h matchpairs
vim.cmd('set mps+=<:>')

vim.opt.signcolumn = "yes:2"

vim.cmd('au BufRead,BufNewFile *.nu		set filetype=nu')
