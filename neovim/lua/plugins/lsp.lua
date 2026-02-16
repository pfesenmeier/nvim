local csharp = require "pfes.lang.csharp"
local vue    = require "pfes.lang.vue"
local deno   = require "pfes.lang.deno"
local env    = require "pfes.env"
local keymap = require "pfes.keymap.lsp"

local lsps   = {
  -- enabled via vscode-langservers-extracted
  -- "html",
  -- "cssls",
  "jsonls",
  "eslint",

  "prismals",
  "tailwindcss",
  "nushell",
  "lua_ls",
  "marksman",
  "terraform-ls"
}

if env.rust then
  table.insert(lsps, "rust_analyzer")
end

local function on_attach(_, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'
  keymap.set(bufnr)
end

local function init()
  -- Enable cmp with lsp servers.
  local capabilities = require('cmp_nvim_lsp').default_capabilities()

  vim.lsp.inlay_hint.enable()

  vim.lsp.config("*", {
    capabilities = capabilities,
    on_attach = on_attach,
  })

  for _, lsp_name in ipairs(lsps) do
    vim.lsp.enable(lsp_name)
  end

  if env.c_sharp then
    csharp.addToLspConfig()
  end

  if env.node then
    vue.addToLspConfig()
  else
    deno.addToLspConfig()
  end
end

return {
  {
    "neovim/nvim-lspconfig",
    lazy = true,
    -- currently will load when nvim-cmp loads cmp-nvim-lsp
    init = init,
    dependencies = {
      "folke/lazydev.nvim",
      ft = "lua", -- only load on lua files
      opts = {
        library = {
          -- See the configuration section for more details
          -- Load luvit types when the `vim.uv` word is found
          { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        },
      },
    },
  },
}
