-- Setup calls for custom libraries under neovim/lua/.
-- Add new modules here rather than creating a per-module plugin/ file.

require("remote").setup()

local later = Config.later

later(function()
  -- Exports HueyBuffer
  require("huey.buffer").setup()
  -- Exports HueyTerm
  require("huey.term").setup()

  require("workspace").setup({})
end)
