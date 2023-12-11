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

vim.cmd([[
  " Expand
  imap <expr> <C-j>   vsnip#expandable()  ? '<Plug>(vsnip-expand)'         : '<C-j>'
  smap <expr> <C-j>   vsnip#expandable()  ? '<Plug>(vsnip-expand)'         : '<C-j>'

  " Expand or jump
  imap <expr> <C-l>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
  smap <expr> <C-l>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'

  " Jump forward or backward
  imap <expr> <Tab>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<Tab>'
  smap <expr> <Tab>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<Tab>'
  imap <expr> <S-Tab> vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>'
  smap <expr> <S-Tab> vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>'

  " Select or cut text to use as $TM_SELECTED_TEXT in the next snippet.
  " See https://github.com/hrsh7th/vim-vsnip/pull/50
  nmap        s   <Plug>(vsnip-select-text)
  xmap        s   <Plug>(vsnip-select-text)
  nmap        S   <Plug>(vsnip-cut-text)
  xmap        S   <Plug>(vsnip-cut-text)
]])

-- command line motions from :h cmdline.txt
vim.api.nvim_set_keymap('c', '<C-A>', '<Home>', opts )
vim.api.nvim_set_keymap('c', '<C-F>', '<Right>', opts )
vim.api.nvim_set_keymap('c', '<C-B>', '<Left>', opts )
-- <S-Right> ... the name for word motion
vim.api.nvim_set_keymap('c', '<Esc>b', '<S-Left>', opts )
vim.api.nvim_set_keymap('c', '<Esc>f', '<S-Right>', opts )

-- common command line motions
map("n", "<leader>w", ":w<CR>", { noremap = true })
map("n", "<leader>x", ":x<CR>", { noremap = true })
map("n", "<leader>q", ":q<CR>", { noremap = true })
map("n", "<leader>;", ":", { noremap = true })
-- go to folder view of current file
map("n", "<leader>o", ":Explore<cr>", opts)
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
  local build_result = os.execute("dotnet build")

  if build_result ~= 0 then
    vim.print("build failed")
    return
  end

  require("neotest").run.run(runArgs)
  vim.notify("build succeed and tests have begun")
end

vim.keymap.set('n', '<leader>tr', function() return DotNetTest() end, { noremap = true })
vim.keymap.set('n', '<leader>tf', function() return DotNetTest(vim.fn.expand("%")) end, { noremap = true })
vim.keymap.set('n', '<leader>td', function() return DotNetTest({vim.fn.expand("%"), strategy = "dap"}) end, { noremap = true })

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
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
-- see lsp.lua where this is being used
local function on_attach(_, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { buffer = bufnr }
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
  vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, bufopts)
  vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
  vim.keymap.set('n', '<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, bufopts)
  vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, bufopts)
  vim.keymap.set({'v', 'n' }, '<leader>ca', vim.lsp.buf.code_action, bufopts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
  vim.keymap.set('n', '<leader>f', function()
    vim.lsp.buf.format { async = true }
  end, bufopts)
end

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

require('gitsigns').setup{
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns

    local function map(mode, l, r, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    -- Navigation
    map('n', ']c', function()
      if vim.wo.diff then return ']c' end
      vim.schedule(function() gs.next_hunk() end)
      return '<Ignore>'
    end, {expr=true})

    map('n', '[c', function()
      if vim.wo.diff then return '[c' end
      vim.schedule(function() gs.prev_hunk() end)
      return '<Ignore>'
    end, {expr=true})

    -- Actions
    map('n', '<leader>hs', gs.stage_hunk)
    map('n', '<leader>hr', gs.reset_hunk)
    map('v', '<leader>hs', function() gs.stage_hunk {vim.fn.line('.'), vim.fn.line('v')} end)
    map('v', '<leader>hr', function() gs.reset_hunk {vim.fn.line('.'), vim.fn.line('v')} end)
    map('n', '<leader>hS', gs.stage_buffer)
    map('n', '<leader>hu', gs.undo_stage_hunk)
    map('n', '<leader>hR', gs.reset_buffer)
    map('n', '<leader>hp', gs.preview_hunk)
    map('n', '<leader>hb', function() gs.blame_line{full=true} end)
    map('n', '<leader>tb', gs.toggle_current_line_blame)
    map('n', '<leader>hd', gs.diffthis)
    map('n', '<leader>hD', function() gs.diffthis('~') end)
--    map('n', '<leader>td', gs.toggle_deleted)

    -- Text object
    map({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
  end
}

return { on_attach = on_attach }
