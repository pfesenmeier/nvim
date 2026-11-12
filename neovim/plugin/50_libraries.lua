-- Setup calls for custom libraries under neovim/lua/.
-- Add new modules here rather than creating a per-module plugin/ file.

local now, later = Config.now, Config.later

-- Runs now, not later, so 'mini.starter' can list projects when it opens
now(function() require('huey.projects').setup() end)

later(function()
  require('huey.buffer').setup()
  require('huey.hub.client').setup()
  require('huey.jj').setup()
  require('huey.termlink').setup()
  require('huey.visits').setup()
end)
