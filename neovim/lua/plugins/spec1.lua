local env = require 'pfes.env'
local sql = env.sql
local c_sharp = env.c_sharp

local packages = {
  -- prevent remote code execution
  { "ciaranm/securemodelines", lazy = true, event = "VeryLazy" },
  { "tommcdo/vim-lion" },
  {
    "Pocco81/auto-save.nvim",
    lazy = true,
    event = "VeryLazy",
    opts = {
      condition = function(buf)
        local name = vim.api.nvim_buf_get_name(buf)
        return name:match('%.spec.cy.ts$') == nil
      end
    },

    init = function()
      vim.api.nvim_set_keymap("n", "<leader>n", ":ASToggle<CR>", {})
    end
  },
  -- workspace defaults to closest .git
  -- trying to use tcd (tab), lcd (window), cd
  {
    "airblade/vim-rooter",
    lazy = false,
    event = "UIEnter",
    init = function()
      local patterns = { '.git', '*.sln' }

      if not env.monorepo then
        table.insert(patterns, "package.json")
        table.insert(patterns, "deno.json")
        table.insert(patterns, "Cargo.toml")
      end

      vim.g.rooter_patterns = patterns
    end
  },
  -- database
  {
    "tpope/vim-dadbod",
    ft = "sql",
    lazy = true,
    enabled = sql,
    dependencies = { "kristijanhusak/vim-dadbod-completion" }
  },
  -- git
  {
    "lewis6991/gitsigns.nvim",
    opts = {},
    tag = "v0.9.0",
    lazy = true,
    event = "VeryLazy"
  },

  {
    "tpope/vim-fugitive",
    lazy = true,
    event = "VeryLazy",
    dependencies = {
      -- enable Gbrowse
      "tpope/vim-rhubarb", -- with Github
      -- "cedarbaum/fugitive-azure-devops.vim", -- with ADO
    }
  },
  {
    "mhartington/formatter.nvim",
    enabled = true,
    config = function(_)
      local function prettierFmt()
        local util = require "formatter.util"
        return {
          exe = "prettier",
          args = {
            "--stdin-filepath",
            util.get_current_buffer_file_path(),
          },
          stdin = true,
          try_node_modules = true,
        }
      end
      require('formatter').setup {
        filetype = {
          typescript = {
            prettierFmt
          },
          vue = {
            prettierFmt
          },
        }
      }

      local function prettier()
        local cwd = vim.uv.cwd()
        local dir = vim.fn.finddir('.git', '.;' .. env.home)

        vim.uv.chdir(dir .. '/..')
        print(vim.uv.cwd())
        vim.api.nvim_exec2("!git diff --name-only | lines |  prettier -w ...$in", {})
        vim.api.nvim_exec2("!git diff --staged --name-only | lines |  prettier -w ...$in", {})
        vim.uv.chdir(cwd)
      end

      vim.api.nvim_create_user_command("P", prettier, { bang = false })
    end,
    init = function()
      vim.keymap.set('n', '<leader><leader>f', ':Format<CR>')
    end
  },
  {
    'windwp/nvim-ts-autotag',
    opts = {},
  },
  {
    'luisiacc/gruvbox-baby',
    init = function()
      -- Enable telescope theme
      vim.g.gruvbox_baby_background_color = 'dark'
      vim.g.gruvbox_baby_transparent_mode = 1
      vim.cmd('colorscheme gruvbox-baby')
    end
  }
}

return packages
