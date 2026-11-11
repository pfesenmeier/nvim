-- Setup calls for custom libraries under neovim/lua/.
-- Add new modules here rather than creating a per-module plugin/ file.

local later = Config.later

later(function()
  require('huey.buffer').setup()
  require('huey.hub.client').setup()
  require('huey.jj').setup()
  require('huey.termlink').setup()
  require('huey.visits').setup()
  -- Machine-specific settings live in the gitignored lua/secrets.lua
  local has_secrets = vim.api.nvim_get_runtime_file('lua/secrets.lua', false)[1] ~= nil
  local secrets = has_secrets and require('secrets') or {}
  require('workspace').setup({ workspaces = secrets.workspaces })
end)
