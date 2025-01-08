local env = require "pfes.env"

local islinux = env.islinux

return {
    {
        'Issafalcon/neotest-dotnet',
        lazy = true,
        enabled = islinux,
        tag = 'v1.5.3',
        ft = { "cs" },
        dependencies = {
            'nvim-neotest/neotest'
        },
    },
    {
        'nvim-neotest/neotest',
        tag = 'v5.2.3',
        lazy = true,
        enabled = islinux,
        dependencies = {
            'antoinemadec/FixCursorHold.nvim',
            'nvim-neotest/nvim-nio',
            "nvim-treesitter/nvim-treesitter",
            'Issafalcon/neotest-dotnet',
        },
        opts = function()
            return {
                adapters = {
                    require("neotest-dotnet")({
                        discovery_root = "solution"
                    })
                }
            }
        end
    },
}
