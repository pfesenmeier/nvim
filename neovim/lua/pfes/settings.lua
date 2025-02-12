local env = require('pfes.env')
vim.g.netrw_browsex_viewer = "msedge.exe"
vim.g.netrw_banner = 0

-- set windows clipboard
vim.opt.clipboard = "unnamedplus"

-- set shell to nushell
-- https://github.com/neovim/neovim/issues/19648#issuecomment-1212295560
vim.opt.shell = "nu"
local config = '--config ' .. env.home .. '/nvim/nushell/config.nu'
local envconfig = '--env-config ' .. env.home .. '/nvim/nushell/env.nu'
vim.opt.shellcmdflag = config .. " " .. envconfig .. " " .. "-c"
vim.opt.shellquote = ""
vim.opt.shellxquote = ""
-- ":r !ls | to text" or ":r !ls | get name"
vim.opt.shellredir = '| save %s'

-- tabs are spaces
vim.opt.tabstop = 2     -- tabs are tabstop spaces long
vim.opt.shiftwidth = 2  -- indents are 4 widths long
vim.opt.softtabstop = 2 -- colunmn??
vim.opt.scrolloff = 999 -- keep cursor in middle of screen
vim.opt.expandtab = true
vim.opt.shellslash = false

-- default highlight group for nvim-dap is a bright blue
vim.api.nvim_set_hl(0, 'debugPC', { bg = '#341F36' })
vim.opt.relativenumber = true
vim.opt.foldenable = false

vim.opt.signcolumn = "yes:2"
vim.opt.fixendofline = false

-- add <> for % moti
-- see :h matchpairs
vim.cmd('set mps+=<:>')

vim.cmd('au BufRead,BufNewFile *.nu		set filetype=nu')

local groupId = vim.api.nvim_create_augroup("TerminalEvents", {})
vim.api.nvim_create_autocmd({ "TermOpen" }, {
  group = groupId,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
  end
})

if vim.g.neovide then
  vim.o.guifont = "0xProto Nerd Font Mono:h14"
  vim.g.neovide_scale_factor = 0.9
  vim.g.neovide_title_background_color = '#000000'
  vim.g.neovide_cursor_animation_length = 0.06

  vim.keymap.set('v', '<C-c>', '"+y')         -- Copy
  vim.keymap.set('n', '<C-v>', '"+P')         -- Paste normal mode
  vim.keymap.set('v', '<C-v>', '"+P')         -- Paste visual mode
  vim.keymap.set('c', '<C-v>', '<C-R>+')      -- Paste command mode
end
