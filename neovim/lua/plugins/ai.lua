return {
  {
    "github/copilot.vim"
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      { "github/copilot.vim" }, -- or zbirenbaum/copilot.lua
      { "nvim-lua/plenary.nvim" }, -- for curl, log and async functions
    },
    opts = {
      allow_insecure = true, -- Allow insecure server connections
    },
  },
}
