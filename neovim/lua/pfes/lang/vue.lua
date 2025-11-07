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
local function findVue(nodeVersion)
  -- too slow
  -- local output = vim.fn.system{ 'npm', 'list', '--global', '--depth', '0', '--parseable', 'typescript' }
  local subpath = "installation/lib/node_modules/@vue/language-server"
  if env.islinux then
    return vim.fs.joinpath(vim.env.HOME, ".local/share/fnm/node-versions", nodeVersion, subpath)
  else
    return vim.fs.joinpath(vim.env.APPDATA, "fnm/node-versions", nodeVersion, subpath)
  end
end

vue.addToLspConfig = function()
  local vue_language_server_path = findVue(env.node)
  local filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' }
  local vue_plugin = {
    name = '@vue/typescript-plugin',
    location = vue_language_server_path,
    languages = { 'vue' },
    configNamespace = 'typescript',
  }
  local vtsls_config = {
    root_markers = { '.git' },
    settings = {
      vtsls = {
        tsserver = {
          globalPlugins = {
            vue_plugin,
          },
        },
      },
    },
    filetypes = filetypes,
  }

  local vue_ls_config = {
    root_markers = { '.git' },
  }

  local ts_ls_config = {
    init_options = {
      plugins = {
        vue_plugin,
      },
    },
    filetypes = filetypes,
    root_markers = { '.git' },
  }

  -- nvim 0.11 or above
  vim.lsp.config('vtsls', vtsls_config)
  vim.lsp.config('vue_ls', vue_ls_config)
  vim.lsp.config('ts_ls', ts_ls_config)

  -- vim.lsp.enable({ 'ts_ls', 'vue_ls' })
  vim.lsp.enable({ 'vtsls', 'vue_ls' })
end

return vue
