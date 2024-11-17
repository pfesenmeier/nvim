local env = require("pfes.env")

local vue = {}

vue.addToLspConfig = function(opts, capabilities, on_attach)
    local util = require 'lspconfig.util'
    opts.volar.setup {
        capabilities = capabilities,
        on_attach = on_attach
    }
    opts.ts_ls.setup {
        -- package.json for ts_ls, deno.json for deno
        root_dir = util.root_pattern('package.json'),
        single_file_support = false,
        init_options = {
            plugins = {
                {
                    name = "@vue/typescript-plugin",
                    location = env.home .. "/.local/share/fnm/node-versions/v20.11.1/installation/lib/node_modules/@vue/language-server/node_modules/@vue/typescript-plugin/",
                    languages = {
                        "javascript",
                        "typescript",
                        "vue"
                    },
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
