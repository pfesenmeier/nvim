require'nvim-treesitter.configs'.setup {
  ensure_installed = { "c_sharp", "javascript", "java", "lua", "rust", "python", "c", "jq", "json5", "json", "markdown", "toml", "typescript", "HCL", "HTML",
    "regex", "sql", "yaml", "gitignore", "gitattributes" }, -- one of "all", "maintained" (parsers with maintainers), or a list of languages
  sync_install = false, -- install languages synchronously (only applied to `ensure_installed`)
  ignore_install = { "gleam", "svelte" }, -- List of parsers to ignore installing
  highlight = {
    enable = true,              -- false will disable the whole extension
    -- disable = { },  -- list of language that will be disabled
    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = false,
  },
  incremental_selection = {
    enable = true,
   -- keymaps = {
   --   init_selection = "gnn",
   --   node_incremental = "grn",
    --  scope_incremental = "grc",
    --  node_decremental = "grm",
   -- },
  },
  indent = {
    enable = true
  }
}

-- enable tree-sitter base folding
vim.cmd('set foldmethod=expr')
vim.cmd('set foldexpr=nvim_treesitter#foldexpr()')

-- for more
-- :h nvim-treesitter-commands
