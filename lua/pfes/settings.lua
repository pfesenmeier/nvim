vim.g.mapleader = " "
vim.g.netrw_browsex_viewer= "msedge.exe"
vim.g.netrw_banner=0

local o = vim.opt
local c = vim.cmd

-- set windows clipboard
c('set clipboard=unnamedplus')

-- tabs are spaces
o.tabstop = 4 -- tabs are tabstop spaces long
o.shiftwidth = 4 -- indents are 4 widths long
o.softtabstop = 4 -- colunmn??
o.scrolloff = 999 -- keep cursor in middle of screen
o.scrolloff = 999
o.expandtab = true

c('set noshellslash')
-- theme stuff
-- o.syntax = 'on'
-- o.termguicolors = true
o.background = "dark"
c([[colorscheme gruvbox]])
-- default highlight group for nvim-dap is a bright blue
vim.api.nvim_set_hl(0, 'debugPC', { bg = '#341F36' })

c('set relativenumber')
c('set nofoldenable')

-- set background transparent (I have background photo via Windows Terminal)
c('highlight Normal guibg=none')
c('highlight NonText guibg=none')

-- add <> for % motion
-- see :h matchpairs
vim.cmd('set mps+=<:>')

vim.opt.signcolumn = "yes:2"

-- ongoing issue: https://github.com/nvim-telescope/telescope.nvim/issues/2712
-- TODO remove boilerplate from file display
require('telescope').setup{
	defaults = {
		path_display={"truncate"}
	}
}
require('telescope').load_extension('fzf')
