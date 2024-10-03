local env = require("pfes.env")

local vue = {}

vue.addToLspConfig = function(opts, capabilities, on_attach)
    opts.ts_ls.setup {
        init_options = {
            plugins = {
                {
                    name = "@vue/typescript-plugin",
                    location = env.home .. "/.local/share/fnm/node-versions/v20.11.1/installation/lib/node_modules/@vue/typescript-plugin",
                    languages = { "javascript", "typescript", "vue" },
                },
            },
        },
        filetypes = {
            "javascript",
            "typescript",
            "vue",
        },
        capabilities = capabilities,
        on_attach = on_attach
    }
end

return vue

