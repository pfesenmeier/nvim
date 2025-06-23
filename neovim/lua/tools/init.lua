#!/usr/bin/env -S nvim -l

local all_packages = require("tools.specs")

local sysname = vim.uv.os_uname().sysname
local is_linux = sysname == "Linux"
local is_windows = string.find(sysname, "Windows") ~= nil

local package_managers = {
  npm = {
    enabled = true,
    cmds = {
      install = { "install", "-g" }
    }
  },
  brew = {
    enabled = is_linux,
  },
  scoop = {
    enabled = is_windows,
  },
  winget = {
    enabled = is_windows,
    cmds = {
      install = { "install", "--no-upgrade", "--accept-package-agreements" }
    }
  },
}

local M = {}

function M.available_packages()
  local result = vim.iter(package_managers):fold({}, function(acc, name, settings)
    if settings.enabled then
      acc[name] = {}
    end

    return acc
  end)

  for _, v in ipairs(all_packages) do
    for key, value in pairs(v.src) do
      if type(key) == "number" and result[value] ~= nil then
        table.insert(result[value], v.name)
        break
      end

      if result[key] ~= nil then
        table.insert(result[key], value)
        break
      end
    end
  end

  return result
end

function M.make_print(tag, key)
  return function(_, data)
    if data ~= nil then
      vim.print(string.format("[%s|%s]: %s", key, tag, data))
    end
  end
end

function M.format_install_cmd(manager, packages)
  local cmd = { manager }

  local install_cmd = vim.tbl_get(package_managers, manager, "cmds", "install") or { "install" }

  vim.list_extend(cmd, install_cmd)
  vim.list_extend(cmd, packages)

  return cmd
end

function M.install(f)
  local filters = f or {}
  local manager_filter = filters.manager

  local to_install = M.available_packages()
  if manager_filter then
    local filtered = {}

    if to_install[manager_filter] then
      filtered[manager_filter] = to_install[manager_filter]

      to_install = filtered
    end
  end

  local processes = {}
  local function make_on_exit(key)
    return function(obj)
      if obj.code == 0 then
        vim.print(string.format("%s succeeded.", key))
      else
        vim.print(string.format("%s failed.", key))
      end
      processes[key] = nil
    end
  end

  for manager, packages in pairs(to_install) do
    local cmd = M.format_install_cmd(manager, packages)
    vim.print(table.concat(cmd, " "))
    processes[manager] = vim.system(cmd, {
        text = true,
        stderr = M.make_print('stderr', manager),
        stdout = M.make_print('stdout', manager)
      },
      make_on_exit(manager))
  end

  vim.wait(1000, function()
    return vim.iter(processes):all(function(_, v)
      return v == nil
    end)
  end)
end

M.install()

return M
