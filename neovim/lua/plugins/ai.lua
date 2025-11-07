return {
  {
    "github/copilot.vim",
    enabled = true,
    init = function()
      vim.g.copilot_filetypes = {
        md = false,
        txt = false
      }
    end
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
  -- https://github.com/zed-industries/claude-code-acp
  {
    "olimorris/codecompanion.nvim",
    opts = {
      -- strategies = {
      --   chat = {
      --     adapter = "claude_code"
      --   },
      --   inline = {
      --     adapter = "claude_code"
      --   },
      --   cmd = {
      --     adapter = "claude_code"
      --   }
      -- },
      display = {
        chat = {
          window = {
            position = 'left',
          }
        }
      },
      adapters = {
        -- acp = {
        --   claude_code = function()
        --     return require("codecompanion.adapters").extend("claude_code", {
        --       env = {
        --         CLAUDE_CODE_OAUTH_TOKEN = "CLAUDE_CODE_OAUTH_TOKEN"
        --       }
        --     })
        --   end,
        -- },
        http = {
          copilot = function()
            return require('codecompanion.adapters').extend('copilot', {
              -- =require('codecompanion.adapters.copilot.helpers').get_models()
              -- gpt-4.1
              -- claude-sonnet-4
              schema = {
                model = {
                  default = "claude-sonnet-4.5"
                }
              }
            })
          end
        }
      }
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
