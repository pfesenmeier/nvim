return {
  {
    -- most of this copied from https://github.com/LazyVim/LazyVim/blob/12818a6cb499456f4903c5d8e68af43753ebc869/lua/lazyvim/plugins/treesitter.lua
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
      "nushell/tree-sitter-nu",
    },
    version = false, -- Lazy does this because does not work on Windows?,
    build = ":TSUpdate",
    event = { "VeryLazy" },
    lazy = vim.fn.argc(-1) == 0, -- Lazy does this: load treesitter early when opening a file from the cmdline

    init = function(plugin)
      require 'nvim-treesitter.install'.compilers = { "gcc", "zig" }
      -- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
      -- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
      -- no longer trigger the **nvim-treesitter** module to be loaded in time.
      -- Luckily, the only things that those plugins need are the custom queries, which we make available
      -- during startup.
      require("lazy.core.loader").add_to_rtp(plugin)
      require("nvim-treesitter.query_predicates")

      -- enable tree-sitter base folding
      vim.cmd('set foldmethod=expr')
      vim.cmd('set foldexpr=nvim_treesitter#foldexpr()')

      vim.filetype.add({
        extension = {
          razor = "html",
          hurl = "hurl"
        }
      })
    end,
    config = function()
      local configs = require("nvim-treesitter.configs")
      configs.setup({
        modules = {},
        auto_install = true,
        ensure_installed = {
          "c_sharp",
          "javascript",
          -- "java",
          "lua",
          "glimmer",
          "rust",
          "diff",
          "python",
          -- "c",
          -- "jq",
          "json5",
          "json",
          "hurl",
          "markdown",
          "markdown_inline",
          "toml",
          "typescript",
          "terraform",
          "hcl",
          "html",
          "regex",
          "prisma",
          "sql",
          "yaml",
          "gitignore",
          "gitattributes",
          "todotxt",
          "tsx",
          "vim",
          "vimdoc",
          "vue",
          "nu"
        },
        sync_install = true,                    -- install languages synchronously (only applied to `ensure_installed`)
        ignore_install = { "gleam", "svelte" }, -- List of parsers to ignore installing
        indent = {
          enable = true
        },
      })
    end,
  },
}
