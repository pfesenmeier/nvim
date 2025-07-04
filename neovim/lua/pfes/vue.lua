local env = require("pfes.env")

local vue = {}

vue.addToDap = function(dap)
  if (dap.configurations.typescript == nil) then
    dap.configurations.typescript = {}
  end

  local configurations = {
    {
      type = "pwa-node",
      request = "launch",
      name = "Vitest",
      cwd = "${workspaceFolder}",
      program = "${workspaceFolder}/node_modules/vitest/vitest.mjs",
      args = { "run", "${file}" },
      autoAttachChildProcesses = true,
      skipFiles = { "<node_internals>/**", "node_modules/**" },
      -- trace = true,
      console = "integratedTerminal",
      sourceMaps = true,
      smartStep = true,
    },
  }

  for _, value in ipairs(configurations) do
    table.insert(dap.configurations.typescript, value)
  end
end

--- @param nodeVersion string
--- @return string
local function findTypescript(nodeVersion)
  -- too slow
  -- local output = vim.fn.system{ 'npm', 'list', '--global', '--depth', '0', '--parseable', 'typescript' }
  local subpath = "installation/lib/node_modules/typescript/lib"
  if env.islinux then
    return vim.fs.joinpath(vim.env.HOME, ".local/share/fnm/node-versions", nodeVersion, subpath)
  else
    return vim.fs.joinpath(vim.env.APPDATA, "fnm/node-versions", nodeVersion, subpath)
  end
end

vue.addToLspConfig = function(opts, capabilities, on_attach)
  opts.volar.setup {
    capabilities = capabilities,
    on_attach = on_attach,
    filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
    init_options = {
      vue = {
        hybridMode = false,
      },
      typescript = {
        tsdk = findTypescript('v22.17.0')
      },
    }

  }
end

return vue
