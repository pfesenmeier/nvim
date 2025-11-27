local M = {}

local all_packages = require "tools.spec"

function M.setup(package_managers, debug)
  M.package_managers = package_managers or {}
  M.all_packages = all_packages
  M.debug = debug or false

  return M
end

function M.is_available(exe)
  return vim.fn.executable(exe) == 1
end

function M.available_packages()
  local result = vim.iter(M.package_managers):fold({}, function(acc, name)
    if M.is_available(name) then
      if M.debug then
        vim.print("Found " .. name)
      end
      acc[name] = {}
    else
      if M.debug then
        vim.print("Missing " .. name)
      end
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

function M.get_install_cmds(manager_filter)
  -- mngr: packages[]
  local available = M.available_packages()

  if manager_filter then
    available = {
      [manager_filter] = available[manager_filter]
    }
  end

  -- mngr: install_cmd
  local result = {}

  for manager, packages in pairs(available) do
    result[manager] = M.format_install_cmd(manager, packages)
  end

  return result
end

function M.install(opts)
  opts = opts or {}
  local manager_filter = opts.manager
  local wait = opts.wait

  local to_install = M.get_install_cmds(manager_filter)

  vim.print(string.format("Enabled package managers: %s", table.concat(vim.tbl_keys(to_install), ", ")))

  for manager, cmd in pairs(to_install) do
    local on_exit = function(obj)
      if obj.code ~= 0 then
        print('code:   ' .. obj.code)
      end

      if obj.signal ~= 0 then
        print('signal: ' .. obj.signal)
      end

      if obj.signal ~= nil then
        print('stdout: ' .. obj.stdout)
      end

      if obj.stderr ~= nil then
        print('stderr: ' .. obj.stderr)
      end
    end

    print("Installing packages with " .. manager .. "...")
    if wait then
      local obj = vim.system(cmd, { text = true }):wait()
      print("Done")
      on_exit(obj)
    else
      vim.system(cmd, { text = true }, on_exit)
    end
  end
end

return M
