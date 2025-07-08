local env = require "pfes.env"

local islinux = env.islinux
local csharp   = require "pfes.lang.csharp"
local deno     = require "pfes.lang.deno"
local vue      = require "pfes.lang.vue"
local lua_lang = require "pfes.lang.lua-lang"

return {
    {
        'mfussenegger/nvim-dap',
        tag = '0.7.0',
        lazy = true,
        ft = { "ts", "tsx", "js", "jsx", "cs", "lua" },
        dependencies = { { 'theHamsta/nvim-dap-virtual-text', opts = {} } },
        config = function()
            local dap = require('dap')
            local vim = vim

            csharp.addToDap(dap, vim)
            deno.addToDap(dap)
            vue.addToDap(dap)
            lua_lang.addToDap(dap)
        end
    },
    {

        'jbyuki/one-small-step-for-vimkind',
        dependencies = { 'mfussenegger/nvim-dap' },
        enabled = islinux,
        init = function()
            vim.keymap.set('n', '<F6>', function()
                require "osv".run_this(require "osv".run_this())
            end, { noremap = true })
        end
    },
    {
        "rcarriga/nvim-dap-ui",
        dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    }
}
