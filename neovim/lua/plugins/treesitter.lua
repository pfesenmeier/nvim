local treesitter_languages = {
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
}

return {
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    dependencies = {
      "nushell/tree-sitter-nu",
    },
    init = function()
      require 'nvim-treesitter'.install(treesitter_languages)
      local ft_patterns = vim.list_extend(
        vim.deepcopy(treesitter_languages),
        { "javascriptreact", "typescriptreact" }
      )
      vim.api.nvim_create_autocmd('FileType', {
        pattern = ft_patterns,
        callback = function() vim.treesitter.start() end,
      })
    end
  },
}
