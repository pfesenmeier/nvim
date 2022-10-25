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

-- quicksave
map("n", "<leader>w", ":w<CR>", { noremap = true })
map("n", "<leader>x", ":x<CR>", { noremap = true })

-- switch mark and buffer commands
map("n", "'" ,'"', { noremap = true })
map("n", '"', "'", { noremap = true })

-- remap colon
map("n", ";", ":", { noremap = true })
map("n", ":", ";", { noremap = true })

map("n", "q", "<c-v>", { noremap = true })

-- open helpers
map("n", "<leader>;", ":buffers", opts)
map("n", "<c-p>", ":files", opts)

-- switch buffers
map("n", "<left>", ":bp<cr>", opts)
map("n", "<right>", ":bn<cr>", opts)

-- move to ends of lines with homerow
map("n", "H", "^", opts)
map("n", "L", "$", opts)

-- go to folder view of current file
map("n", "<leader>o", ":Explore<cr>", opts)

-- toggle buffers
map("n", "<leader><leader>", "<c-^>", opts)

-- functions eagerly load module. see :help vim.keymap.set()
vim.keymap.set("n", "<leader>rg", function() return require('telescope.builtin').live_grep() end, opts)
vim.keymap.set("n", "<leader>fd", function() return require('telescope.builtin').find_files() end, opts)
vim.keymap.set("n", "<leader>fb", function() return require('telescope.builtin').buffers() end, opts)
vim.keymap.set("n", "<leader>fh", function() return require('telescope.builtin').help_tags() end, opts)

-- Language server shortcuts from https://github.com/neovim/nvim-lspconfig
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
vim.keymap.set('n', 'gE', vim.diagnostic.goto_prev, opts)
vim.keymap.set('n', 'ge', vim.diagnostic.goto_next, opts)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)

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
  vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
  vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
  vim.keymap.set('n', '<space>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, bufopts)
  vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
  vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
  vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
  vim.keymap.set('n', '<leader>m', vim.lsp.buf.formatting, bufopts)
end

local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())

vim.keymap.set('n', '<leader>t', function() return require('lsp_extensions').inlay_hints { only_current_line = true } end)
vim.keymap.set('n', '<leader>T', function() return require('lsp_extensions').inlay_hints() end)

return { on_attach = on_attach }
