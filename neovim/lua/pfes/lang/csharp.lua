local env                      = require "pfes.env";

local csharp                   = {}

csharp.addToLspConfig          = function()
  vim.lsp.config("roslyn_ls", {
    cmd = csharp.getStartupCommand()
  })
  vim.lsp.enable('roslyn_ls')
end

csharp.getStartupCommand       = function()
  local default = {
    env.roslyn_lsp,
    '--logLevel',              -- this property is required by the server
    'Information',
    '--extensionLogDirectory', -- this property is required by the server
    vim.fs.joinpath(vim.uv.os_tmpdir(), 'roslyn_ls/logs'),
    '--stdio',
  }


  if (env.roslynator_dir) then
    for name, _ in vim.fs.dir(env.roslynator_dir) do
      local path = vim.fs.joinpath(env.roslynator_dir, name)

      table.insert(default, "--extension")
      table.insert(default, path)
    end
  end

  return default
end

csharp.addToDap                = function(dap, vim)
  vim.g.dotnet_build_project = function()
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

  -- https://github.com/mfussenegger/nvim-dap/wiki/Cookbook#making-debugging-net-easier
  vim.g.dotnet_get_dll_path = function()
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

  local config = {
    {
      type = "netcoredbg",
      name = "launch - netcoredbg",
      request = "launch",
      program = function()
        if vim.fn.confirm('Should I recompile first?', '&yes\n&no', 2) == 1 then
          vim.g.dotnet_build_project()
        end
        return vim.g.dotnet_get_dll_path()
      end,
    },
    {
      type = "netcoredbg",
      request = "attach",
      name = "attach - netcoredbg",
      processId = require('dap.utils').pick_process,
      args = {},
    },
  }

  local netcoredbg

  if env.islinux then
    netcoredbg = env.home .. '/.local/bin/Samsung/netcoredbg/netcoredbg/netcoredbg'
  else
    netcoredbg = env.home .. '\\AppData\\Local\\Samsung\\netcoredbg\\netcoredbg\\netcoredbg.exe'
  end

  -- if experiencing problems, make sure treesitter is up to date first!
  dap.adapters.netcoredbg = {
    type = 'executable',
    command = netcoredbg,
    args = { '--interpreter=vscode' }
  }

  dap.configurations.cs = config
  dap.configurations.fsharp = config
end

return csharp
