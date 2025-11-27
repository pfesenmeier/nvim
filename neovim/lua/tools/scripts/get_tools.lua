#!/usr/bin/env -S nvim -l
local package_managers = require("tools.package_managers").package_managers
local helpers = require "tools.helpers".setup(package_managers)

local cmds = helpers.get_install_cmds()
local json = vim.json.encode(cmds, { indent = true })

-- needed to print to stdout
io.stdout:write(json)

