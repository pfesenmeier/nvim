local M = {}

local all_packages = require "tools.specs"

function M.setup(package_managers)
  M.package_managers = package_managers or {}
  M.all_packages = all_packages

  return M
end

function M.available_packages()
  local result = vim.iter(M.package_managers):fold({}, function(acc, name, settings)
    if settings.enabled then
      acc[name] = {}
    end

    return acc
  end)

  for _, v in ipairs(M.all_packages) do
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

function M.format_install_cmd(manager, packages)
  local cmd = { manager }

  local install_cmd = vim.tbl_get(M.package_managers, manager, "cmds", "install") or { "install" }

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

  vim.print(string.format("Enabled package managers: %s", table.concat(vim.tbl_keys(to_install), ", ")))
  for manager, packages in pairs(to_install) do
    local cmd = M.format_install_cmd(manager, packages)

    vim.print("running command:")
    vim.print(table.concat(cmd, " "))
    local result = vim.system(cmd):wait()
    if result.code ~= 0 then
      vim.print("error")
      vim.print(result.stderr)
    else
     vim.print("done.")
    end
  end
end

return M
