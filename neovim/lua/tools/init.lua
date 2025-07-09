#!/usr/bin/env -S nvim -l

local env = require "pfes.env"

local package_managers = {
  npm = {
    enabled = true,
    cmds = {
      install = { "install", "-g" }
    }
  },
  brew = {
    enabled = env.islinux,
  },
  scoop = {
    enabled = env.iswindows,
  },
  winget = {
    enabled = env.iswindows,
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
