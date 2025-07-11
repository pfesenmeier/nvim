local env = require"pfes.env"
local stew = require"pfes.lang.stew"

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


    local configurations = {
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
        {
            type = 'pwa-node',
            request = 'launch',
            name = "Stew Run",
            runtimeExecutable = "deno",
            runtimeArgs = {
                "run",
                "--inspect-wait",
                "--allow-all"
            },
            args = stew.select_recipe,
            program = "${file}",
            cwd = "${workspaceFolder}",
            attachSimplePort = 9229,
        },
    }

    if dap.configurations.typescript == nil then
        dap.configurations.typescript = {}
    end

    for _, value in ipairs(configurations) do
        table.insert(dap.configurations.typescript, value)
    end
end

deno.addToLspConfig = function()
    vim.g.markdown_fenced_languages = {
        "ts=typescript"
    }

    vim.lsp.config("denols",{
      -- deno monorepos deno.json files in root and leaf directories
      root_markers = { '.git' },
    })
    vim.lsp.enable("denols")
end

return deno
