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
-- o.scrolloff = 999 -- keep cursor in middle of screen
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

-- ongoing issue: https://github.com/nvim-telescope/telescope.nvim/issues/2712
require('telescope').setup{
	defaults = {
		path_display={"truncate"}
	}
}

vim.g.rooter_patterns = {'.git', 'Makefile', '*.sln', 'build/env.sh'}

vim.cmd('au BufRead,BufNewFile *.nu		set filetype=nu')
require('Comment').setup()

require('gitsigns').setup()

require("trouble").setup({
-- settings without a patched font or icons
    icons = false,
    fold_open = "v", -- icon used for open folds
    fold_closed = ">", -- icon used for closed folds
    -- indent_lines = true, -- add an indent guide below the fold icons
    signs = {
        -- icons / text used for a diagnostic
        error = "error",
        warning = "warn",
        hint = "hint",
        information = "info"
    },
    -- use_diagnostic_signs = true -- enabling this will use the signs defined in your lsp client
})

require("gruvbox").setup({
  contrast = "hard", -- can be "hard", "soft" or empty string
  transparent_mode = true,
})
vim.cmd("colorscheme gruvbox")
