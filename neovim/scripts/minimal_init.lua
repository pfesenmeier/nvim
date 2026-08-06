-- Minimal init for 'tests/'. Run from the 'neovim' directory:
--   nvim --headless --noplugin -u scripts/minimal_init.lua -c 'lua MiniTest.run()'
-- or `nv test`.

-- `package.path` rather than mini.nvim's `let &rtp.=','.getcwd()`: adding this
-- directory to 'runtimepath' would source 'plugin/', whose files call
-- `Config.later`, which does not exist without the real 'init.lua'.
local cwd = vim.fn.getcwd()
package.path = cwd .. '/lua/?.lua;' .. cwd .. '/lua/?/init.lua;' .. package.path

if #vim.api.nvim_list_uis() == 0 then
  vim.cmd('set rtp+=' .. vim.fn.stdpath('data') .. '/site/pack/core/opt/mini.nvim')
  require('mini.test').setup()
end
