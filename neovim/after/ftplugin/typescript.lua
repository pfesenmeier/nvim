-- deno config
vim.b.markdown_fenced_languages = {
  "ts=typescript"
}

local ok, dap = pcall(require, 'dap')
if not ok then return end

dap.configurations.typescript = {}
dap.adapters["pwa-node"] = {
    type = "server",
    host = "localhost",
    port = "${port}",
    executable = {
      command = "node",
      args = { Config.env.binDir .. "/microsoft/vscode-js-debug/js-debug/src/dapDebugServer.js", "${port}" },
    }
}

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
    }
}

for _, value in ipairs(configurations) do
  table.insert(dap.configurations.typescript, value)
end
