-- dap configuration
local dotnet_build_project = function()
  local default_path = vim.fn.getcwd() .. '/'
  if vim.g['dotnet_last_proj_path'] ~= nil then
    default_path = vim.g['dotnet_last_proj_path']
  end
  local path = vim.fn.input('Path to your *proj file ', default_path, 'file')
  vim.g['dotnet_last_proj_path'] = path
  local cmd = 'dotnet build -c Debug ' .. path
  print('')
  print('Cmd to execute: ' .. cmd)
  local f = os.execute(cmd)
  if f == 0 then
    print('\nBuild: ✔️ ')
  else
    print('\nBuild: ❌ (code: ' .. f .. ')')
  end
end

local dotnet_get_dll_path = function()
  local request = function()
    return vim.fn.input('Path to dll', vim.fn.getcwd(), 'file')
  end

  if vim.g['dotnet_last_dll_path'] == nil then
    vim.g['dotnet_last_dll_path'] = request()
  else
    if vim.fn.confirm('Do you want to change the path to dll?\n' .. vim.g['dotnet_last_dll_path'], '&yes\n&no', 2) == 1 then
      vim.g['dotnet_last_dll_path'] = request()
    end
  end

  return vim.g['dotnet_last_dll_path']
end

local get_latest_dotnet = function()
  local pid_cmd = "ps | where name == dotnet | last | get -o pid"

  local shell = require('util.shell').shell

  local pid = shell(pid_cmd)

  vim.notify("pid: " .. pid)

  return tonumber(pid)
end

local dap_config = {
  {
    type = "netcoredbg",
    name = "launch - netcoredbg",
    request = "launch",
    program = function()
      if vim.fn.confirm('Should I recompile first?', '&yes\n&no', 2) == 1 then
        dotnet_build_project()
      end
        dotnet_get_dll_path()
    end,
  },
  {
    type = "netcoredbg",
    request = "attach",
    name = "attach - netcoredbg",
    processId = get_latest_dotnet,
    args = {},
  },
}

Config.later(function()
  local islinux = Config.env.islinux
  local home = Config.env.home
  local dap = require('dap')

  local netcoredbg
  if islinux then
    netcoredbg = home .. '/.local/bin/Samsung/netcoredbg/netcoredbg/netcoredbg'
  else
    netcoredbg = home .. '\\AppData\\Local\\Samsung\\netcoredbg\\netcoredbg\\netcoredbg.exe'
  end

  -- if experiencing problems, make sure treesitter is up to date first!
  dap.adapters.netcoredbg = {
    type = 'executable',
    command = netcoredbg,
    args = { '--interpreter=vscode' }
  }

  dap.configurations.cs = dap_config
  dap.configurations.fsharp = dap_config
end)
