local env = require("pfes.env")

local deno = {}

deno.addToDap = function(dap)
    dap.adapters["pwa-node"] = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
            command = "node",
            args = { env.binDir .. "/microsoft/vscode-js-debug/js-debug/src/dapDebugServer.js", "${port}" },
        }
    }

    dap.configurations.typescript = {
        {
            type = 'pwa-node',
            request = 'launch',
            name = "Deno Run",
            runtimeExecutable = "deno",
            runtimeArgs = {
                "run",
                "--inspect-wait",
                "--allow-all"
            },
            program = "${file}",
            cwd = "${workspaceFolder}",
            attachSimplePort = 9229,
        },
        {
            type = 'pwa-node',
            request = 'launch',
            name = "Deno Test",
            runtimeExecutable = "deno",
            runtimeArgs = {
                "test",
                "--inspect-wait",
                "--allow-all"
            },
            program = "${file}",
            cwd = "${workspaceFolder}",
            attachSimplePort = 9229,
        },
    }
end

deno.addToLspConfig = function(opts, capabilities, on_attach)
    vim.g.markdown_fenced_languages = {
      "ts=typescript"
    }

    local util = require 'lspconfig.util'
    opts.denols.setup {
        -- package.json for ts_ls
        root_dir = util.root_pattern('deno.json'),
        capabilities = capabilities,
        on_attach = on_attach
    }
end

return deno
