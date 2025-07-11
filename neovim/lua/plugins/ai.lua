return {
  {
    "github/copilot.vim"
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = false,
    dependencies = {
      { "github/copilot.vim" },    -- or zbirenbaum/copilot.lua
      { "nvim-lua/plenary.nvim" }, -- for curl, log and async functions
    },
    opts = {
      allow_insecure = true, -- Allow insecure server connections
    },
    init = function()
      -- Suggested keymaps
      vim.keymap.set("n", "<leader>cc", "<cmd>CopilotChat<cr>", { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>cC", "<cmd>CopilotChatToggle<cr>", { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>cA", "<cmd>CopilotChatAdd<cr>", { noremap = true, silent = true })
      vim.keymap.set("n", "<leader>cR", "<cmd>CopilotChatRemove<cr>", { noremap = true, silent = true })

      vim.ui.select = require('mini.pick').ui_select

    end,
  },
  {
    "olimorris/codecompanion.nvim",
    opts = {
      display = {
        chat = {
          window = {
            position = 'left',
          }
        }
      },
      adapters = {
        copilot = function()
          return require('codecompanion.adapters').extend('copilot', {
            -- =require('codecompanion.adapters.copilot.helpers').get_models()
            -- gpt-4.1
            -- claude-sonnet-4
            schema = {
              model = {
                default = "claude-3.5-sonnet"
              }
            }
          })
        end
      }
      -- these are the default
      -- strategies = {
      --   chat = {
      --     adapter = "copilot"
      --   },
      --   inline = {
      --     adapter = "copilot"
      --   },
      --   cmd = {
      --     adapter = "copilot"
      --   }
      -- }
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "MeanderingProgrammer/render-markdown.nvim",
      "echasnovski/mini.nvim",
      "HakonHarnes/img-clip.nvim",
      -- "ravitemer/mcphub.nvim"
    },
    init = function()
      -- suggested
      --
      vim.keymap.set({ "n", "v" }, "<C-a>", "<cmd>CodeCompanionActions<cr>", { noremap = true, silent = true })
      vim.keymap.set({ "n", "v" }, "<leader>a", "<cmd>CodeCompanionChat Toggle<cr>",
        { noremap = true, silent = true })
      vim.keymap.set("v", "ga", "<cmd>CodeCompanionChat Add<cr>", { noremap = true, silent = true })

      -- Expand 'cc' into 'CodeCompanion' in the command line
      vim.cmd([[cab cc CodeCompanion]])
      vim.ui.select = require('mini.pick').ui_select
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "codecompanion" }
  },
  {
    "echasnovski/mini.diff",
    config = function()
      local diff = require("mini.diff")
      diff.setup({
        -- Disabled by default
        source = diff.gen_source.none(),
      })
    end,
  },
  {
    "HakonHarnes/img-clip.nvim",
    opts = {
      filetypes = {
        codecompanion = {
          prompt_for_file_name = false,
          template = "[Image]($FILE_PATH)",
          use_absolute_path = true,
        },
      },
    },
  },
}
