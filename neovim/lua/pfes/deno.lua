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

return deno
