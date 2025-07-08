local env             = require "pfes.env";

local csharp          = {}

csharp.addToLspConfig = function()
  local omnisharp_dll

  if env.islinux then
    omnisharp_dll = env.home .. "/.local/bin/OmniSharp/omnisharp-roslyn/OmniSharp.dll"
  else
    omnisharp_dll = env.home .. "/AppData/Local/OmniSharp/omnisharp-roslyn/OmniSharp.dll"
  end

  vim.lsp.config("omnisharp", {

    handlers = {
      ["textDocument/definition"] = require('omnisharp_extended').handler,
    },
    cmd = { "dotnet", omnisharp_dll },

    settings = {
      FormattingOptions = {
        -- Enables support for reading code style, naming convention and analyzer
        -- settings from .editorconfig.
        EnableEditorConfigSupport = true,
        -- Specifies whether 'using' directives should be grouped and sorted during
        -- document formatting.
        OrganizeImports = true,
      },
      MsBuild = {
        -- If true, MSBuild project system will only load projects for files that
        -- were opened in the editor. This setting is useful for big C# codebases
        -- and allows for faster initialization of code navigation features only
        -- for projects that are relevant to code that is being edited. With this
        -- setting enabled OmniSharp may load fewer projects and may thus display
        -- incomplete reference lists for symbols.
        LoadProjectsOnDemand = nil,
      },
      RoslynExtensionsOptions = {
        -- Enables support for roslyn analyzers, code fixes and rulesets.
        EnableAnalyzersSupport = true,
        -- Enables support for showing unimported types and unimported extension
        -- methods in completion lists. When committed, the appropriate using
        -- directive will be added at the top of the current file. This option can
        -- have a negative impact on initial completion responsiveness,
        -- particularly for the first few completion sessions after opening a
        -- solution.
        EnableImportCompletion = true,
        -- Only run analyzers against open files when 'enableRoslynAnalyzers' is
        -- true
        AnalyzeOpenDocumentsOnly = nil,
      },
      Sdk = {
        -- Specifies whether to include preview versions of the .NET SDK when
        -- determining which version to use for project loading.
        IncludePrereleases = true,
      },
    },
  })
  vim.lsp.enable("omnisharp")
end

csharp.addToDap       = function(dap, vim)
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
