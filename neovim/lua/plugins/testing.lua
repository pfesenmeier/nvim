return {
    {
        'Issafalcon/neotest-dotnet',
        lazy = true,
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
