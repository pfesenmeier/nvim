local package_managers = {
  npm = {
    cmds = {
      install = { "install", "-g" }
    }
  },
  brew = {},
  scoop = {},
  winget = {
    cmds = {
      install = { "install", "--no-upgrade", "--accept-package-agreements" }
    }
  },
}

local helpers = require "tools.helpers".setup(package_managers)

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("ToolsInstall", function(args)
    local manager = args.fargs[1] or nil

    if manager then
      helpers.install({ manager = manager })
      return
    end

    helpers.install()
  end, { nargs = "?" })
end

return M
