local env = require("pfes.env")

local lua_lang = {}

-- https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#lua
lua_lang.addToDap = function(dap)
    dap.configurations.lua = {
        {
            type = 'nlua',
            request = 'attach',
            name = "Attach to running Neovim instance",
        }
    }

    dap.adapters.nlua = function(callback, config)
        callback({ type = 'server', host = config.host or "127.0.0.1", port = config.port or 8086 })
    end
    -- dap.adapters["local-lua"] = {
    --     type = "executable",
    --     command = "node",
    --     args = {
    --         env.binDir .. "tomblind/local-lua-debugger-vscode/extension/debugAdapter.js"
    --     },
    --     enrich_config = function(config, on_config)
    --         if not config["extensionPath"] then
    --             local c = vim.deepcopy(config)
    --             -- 💀 If this is missing or wrong you'll see
    --             -- "module 'lldebugger' not found" errors in the dap-repl when trying to launch a debug session
    --             print (c.extensionPath)
    --             c.extensionPath = env.binDir .. "/tomblind/local-lua-debugger-vscode/"
    --             on_config(c)
    --         else
    --             on_config(config)
    --         end
    --     end,
    -- }
    --
    -- -- https://zignar.net/2023/06/10/debugging-lua-in-neovim/#debugging-lua
    -- dap.configurations.lua = {
    --     {
    --         name = 'Current file (local-lua-dbg, lua)',
    --         type = 'local-lua',
    --         request = 'launch',
    --         cwd = '${workspaceFolder}',
    --         program = {
    --             lua = 'luajit',
    --             file = '${file}',
    --         },
    --         args = {},
    --     },
    -- }
end

lua_lang.addToLspConfig = function(opts, capabilities, on_attach)
end

return lua_lang
