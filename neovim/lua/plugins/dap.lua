local csharp = require"pfes.csharp"

return {
    {
        'mfussenegger/nvim-dap',
        tag = '0.7.0',
        lazy = true,
        ft = { "ts", "tsx", "js", "jsx", "cs" },
        dependencies = { { 'theHamsta/nvim-dap-virtual-text', opts = {} } },
        config = function()
            local dap = require('dap')
            local vim = vim

            csharp.addToDap(dap, vim)
        end
    },
}
