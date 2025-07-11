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
  local vue_language_server_path = findVue('v22.17.0')
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
    filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
  }

  local vue_ls_config = {
    root_markers = { '.git' },
    on_init = function(client)
      client.handlers['tsserver/request'] = function(_, result, context)
        local clients = vim.lsp.get_clients({ bufnr = context.bufnr, name = 'vtsls' })
        if #clients == 0 then
          vim.notify('Could not found `vtsls` lsp client, vue_lsp would not work without it.', vim.log.levels.ERROR)
          return
        end
        local ts_client = clients[1]

        local param = unpack(result)
        local id, command, payload = unpack(param)
        ts_client:exec_cmd({
          title = 'vue_request_forward', -- You can give title anything as it's used to represent a command in the UI, `:h Client:exec_cmd`
          command = 'typescript.tsserverRequest',
          arguments = {
            command,
            payload,
          },
        }, { bufnr = context.bufnr }, function(_, r)
          local response_data = { { id, r.body } }
          ---@diagnostic disable-next-line: param-type-mismatch
          client:notify('tsserver/response', response_data)
        end)
      end
    end,
  }
  -- nvim 0.11 or above
  vim.lsp.config('vtsls', vtsls_config)
  vim.lsp.config('vue_ls', vue_ls_config)
  if env.node then
    vim.lsp.enable({ 'vtsls', 'vue_ls' })
  end
end

return vue
