-- Setup calls for custom libraries under neovim/lua/.
-- Add new modules here rather than creating a per-module plugin/ file.

local later = Config.later

later(function()
  require("huey.buffer").setup()
  require("workspace").setup({})
end)
