-- gx opens links!!

-- https://www.notonlycode.org/neovim-lua-config/
local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- reload lua files require'd by init.lua
-- from https://neovim.discourse.group/t/reload-init-lua-and-all-require-d-scripts/971/11
-- does not remove old keymaps
function _G.ReloadConfig()
  for name, _ in pairs(package.loaded) do
    if name:match('^pfes') then
      package.loaded[name] = nil
    end
  end

  dofile(vim.env.MYVIMRC)
end

vim.keymap.set('n', '<leader>r', ReloadConfig, { noremap = true })

-- to wipe out all buffers: %bw

-- :h vsnip-mapping

-- paste over something in visual mode without changing buffer
vim.api.nvim_set_keymap("x", "<leader>p", "\"_dP", opts)

-- command line motions from :h cmdline.txt
vim.api.nvim_set_keymap('c', '<C-A>', '<Home>', opts )
vim.api.nvim_set_keymap('c', '<C-F>', '<Right>', opts )
vim.api.nvim_set_keymap('c', '<C-B>', '<Left>', opts )

-- <S-Right> ... the name for word motion
vim.api.nvim_set_keymap('c', '<Esc>b', '<S-Left>', opts )
vim.api.nvim_set_keymap('c', '<Esc>f', '<S-Right>', opts )

vim.api.nvim_set_keymap('n', '<leader>e', ':e %:h<CR>', opts )

-- common command line motions
map("n", "<leader>w", ":w<CR>", { noremap = true })
map("n", "<leader>x", ":x<CR>", { noremap = true })
vim.keymap.set("n", "<leader>q", ":silent :w <bar> :DB < %<CR>", opts)
map("n", "<leader>;", ":", { noremap = true })
-- toggle buffers
map("n", "<leader><leader>", "<c-^>", opts)
-- idea is to have quick solution to paste same content multiple times
-- will not have access to cut content...
-- v_P does same thing?
map("n", "<leader>p", "\"0p", { noremap = true })

-- TODO
-- vs +terminal\ nu.exe will open terminal

-- use <c-q> for visual block mode on windows

-- open helpers
-- map("n", "<leader>;", ":buffers", opts)
map("n", "<c-p>", ":files", opts)

-- :b, :f (buffer/file name) auto-completes!!
function DotNetTest(runArgs)
  vim.notify("building solution...")
  -- local build_result = os.execute("dotnet build")
  --
  -- if build_result ~= 0 then
  --   vim.print("build failed")
  --   return
  -- end

  require("neotest").run.run(runArgs)
  vim.notify("build succeed and tests have begun")
end

vim.keymap.set('n', '<leader>tr', function() return DotNetTest() end, { noremap = true })
vim.keymap.set('n', '<leader>tf', function() return DotNetTest(vim.fn.expand("%")) end, { noremap = true })
-- vim.keymap.set('n', '<leader>td', function() return DotNetTest({vim.fn.expand("%"), strategy = "dap"}) end, { noremap = true })
vim.keymap.set('n', '<leader>td', function() return DotNetTest({strategy = "dap"}) end, { noremap = true })
vim.keymap.set('n', '<leader>tt', function()
    require('neotest').summary.toggle()
end, opts)
vim.keymap.set('n', '<leader>to', function()
    require('neotest').summary.open()
    vim.cmd(':wincmd l', opts)
end, opts)
vim.keymap.set('n', '<leader>tc', function()
    require('neotest').summary.close()
end, opts)

-- switch buffers
map("n", "<left>", ":bp<cr>", opts)
map("n", "<right>", ":bn<cr>", opts)

-- move to ends of lines with homerow
map("n", "H", "^", opts)
map("n", "L", "$", opts)


-- functions eagerly load module. see :help vim.keymap.set()
-- :h telescope.defaults
vim.keymap.set("n", "<leader>rg", function() return require('telescope.builtin').live_grep({ path_display = { "truncate" }}) end, opts)
vim.keymap.set("n", "<leader>fd", function() return require('telescope.builtin').find_files({ path_display = { "truncate" }}) end, opts)

vim.keymap.set("n", "<leader>rG", function() return require('telescope.builtin').live_grep({ cwd = Env.home, path_display = { "truncate" }}) end, opts)
vim.keymap.set("n", "<leader>fD", function() return require('telescope.builtin').find_files({ cwd = Env.home, path_display = { "truncate" }}) end, opts)

vim.keymap.set("n", "<leader>fb", function() return require('telescope.builtin').buffers() end, opts)
vim.keymap.set("n", "<leader>fh", function() return require('telescope.builtin').help_tags() end, opts)
vim.keymap.set("n", "<leader>ft", function() return require('telescope.builtin').treesitter() end, opts)
vim.keymap.set("n", "<leader>fc", function() return require('telescope.builtin').git_bcommits() end, opts)
vim.keymap.set("n", "<leader>rr", function() return require('telescope.builtin').resume() end, opts)

-- Language server shortcuts from https://github.com/neovim/nvim-lspconfig
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<leader>E', vim.diagnostic.open_float, opts)
local err_opts = { severity = vim.diagnostic.severity.ERROR } 
vim.keymap.set('n', 'gE', function() return vim.diagnostic.goto_prev(err_opts) end, opts)
vim.keymap.set('n', 'ge', function() return vim.diagnostic.goto_next(err_opts) end, opts)
vim.keymap.set('n', 'gW', vim.diagnostic.goto_prev, opts)
vim.keymap.set('n', 'gw', vim.diagnostic.goto_next, opts)
-- vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)

vim.keymap.set('n', '<F5>', function() require('dap').continue() end)
vim.keymap.set('n', '<F10>', function() require('dap').step_over() end)
vim.keymap.set('n', '<F11>', function() require('dap').step_into() end)
vim.keymap.set('n', '<F12>', function() require('dap').step_out() end)
vim.keymap.set('n', '<Leader>b', function() require('dap').toggle_breakpoint() end)
vim.keymap.set('n', '<Leader>B', function() require('dap').set_breakpoint() end)
vim.keymap.set('n', '<Leader>lp', function() require('dap').set_breakpoint(nil, nil, vim.fn.input('Log point message: ')) end)
vim.keymap.set('n', '<Leader>dr', function() require('dap').repl.open() end)
vim.keymap.set('n', '<Leader>dl', function() require('dap').run_last() end)
vim.keymap.set({'n', 'v'}, '<Leader>dh', function()
  require('dap.ui.widgets').hover()
end)
vim.keymap.set({'n', 'v'}, '<Leader>dp', function()
  require('dap.ui.widgets').preview()
end)
vim.keymap.set('n', '<Leader>df', function()
  local widgets = require('dap.ui.widgets')
  widgets.centered_float(widgets.frames)
end)
vim.keymap.set('n', '<Leader>ds', function()
  local widgets = require('dap.ui.widgets')
  widgets.centered_float(widgets.scopes)
end)
