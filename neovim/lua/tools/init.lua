local package_managers = require("tools.package_managers").package_managers
local helpers = require "tools.helpers".setup(package_managers)

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("ToolsInstall", function(args)
    local manager = args.fargs[1] or nil
    local wait = args.bang

    if manager then
      helpers.install({ manager = manager, wait = wait })
      return
    end

    helpers.install({ wait = wait })
  end, { nargs = "?", bang = true })
end

return M
