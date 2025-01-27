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
  return env.home .. "/scoop/persist/nvm/nodejs/" .. nodeVersion .. "/node_modules/typescript/lib"
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
            tsdk = findTypescript('v22.9.0')
          },
        }

    }
end

-- vue.addToLspConfig = function(opts, capabilities, on_attach)
--     local util = require 'lspconfig.util'
--     opts.volar.setup {
--         capabilities = capabilities,
--         on_attach = on_attach
--     }
--     opts.ts_ls.setup {
--         -- package.json for ts_ls, deno.json for deno
--         root_dir = util.root_pattern('package.json'),
--         single_file_support = false,
--         init_options = {
--             plugins = {
--                 {
--                     name = "@vue/typescript-plugin",
--                     location = env.home .. "/.local/share/fnm/node-versions/v20.11.1/installation/lib/node_modules/@vue/language-server/node_modules/@vue/typescript-plugin/",
--                     languages = {
--                         "javascript",
--                         "typescript",
--                         "vue"
--                     },
--                 },
--             },
--         },
--         filetypes = {
--             "javascript",
--             "typescript",
--             "vue",
--         },
--         capabilities = capabilities,
--         on_attach = on_attach
--     }
-- end

return vue
