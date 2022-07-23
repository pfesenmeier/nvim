-- TODO tree command

-- https://www.notonlycode.org/neovim-lua-config/
local map = vim.api.nvim_set_keymap
local opts = { noremap=true, silent=true }

-- reload lua files require'd by init.lua
-- from https://neovim.discourse.group/t/reload-init-lua-and-all-require-d-scripts/971/11
-- does not remove keymaps
function _G.ReloadConfig()
  for name,_ in pairs(package.loaded) do
    if name:match('^pfes') then
      package.loaded[name] = nil
    end
  end

  dofile(vim.env.MYVIMRC)
end
map("n", "<leader>r", ":lua ReloadConfig()<CR>", opts)

-- quicksave
map("n", "<leader>w", ":w<CR>", { noremap = true })

-- remap colon
map("n", ";", ":", opts)

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

-- Fuzzy finding
map("n", "<leader>rg", ":Telescope live_grep<cr>", opts)
map("n", "<leader>fd", ":Telescope find_files<cr>", opts)
map("n", "<leader>fb", ":Telescope buffers<cr>", opts)
map("n", "<leader>fh", ":Telescope help_tags<cr>", opts)

-- Language server shortcuts from https://github.com/neovim/nvim-lspconfig
-- Mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float, opts)
vim.keymap.set('n', 'gE', vim.diagnostic.goto_prev, opts)
vim.keymap.set('n', 'ge', vim.diagnostic.goto_next, opts)
vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist, opts)

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap=true, silent=true, buffer=bufnr }
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
  vim.keymap.set('n', '<space>f', vim.lsp.buf.formatting, bufopts)
end

-- export this on_attach variable

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = { 'yamlls', 'rust_analyzer', 'tsserver', 'eslint', 'html', 'jsonls', 'cssls', 'tailwindcss', 'sumneko_lua' }
for _, lsp in pairs(servers) do
  require('lspconfig')[lsp].setup {
    on_attach = on_attach,
  }
end

-- inlay hints
map("n", "<leader>t", ":lua require'lsp_extensions'.inlay_hints{ only_current_line = true }<cr>", opts)
map("n", "<leader>T", ":lua require'lsp_extensions'.inlay_hints()<cr>", opts)
