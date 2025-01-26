local env = require "pfes.env"

local islinux = env.islinux

local sql = false
local c_sharp = false

local packages = {
    -- prevent remote code execution
    { "ciaranm/securemodelines",       lazy = true, event = "VeryLazy" },
    {
        "Pocco81/auto-save.nvim",
        lazy = true,
        event = "VeryLazy",
        init = function()
            vim.api.nvim_set_keymap("n", "<leader>n", ":ASToggle<CR>", {})
        end
    },
    -- workspace defaults to closest .git
    -- trying to use tcd (tab), lcd (window), cd
    {
        "airblade/vim-rooter",
        lazy = false,
        event = "UIEnter",
        init = function()
            vim.g.rooter_patterns = { '.git', 'package.json', 'deno.json', '*.sln'  }
        end
    },
    -- database
    {
        "tpope/vim-dadbod",
        ft = "sql",
        lazy = true,
        enabled = sql,
        dependencies = { "kristijanhusak/vim-dadbod-completion" }
    },
    -- workspace errors
    -- inspect decompiled C#
    {
        "Hoffs/omnisharp-extended-lsp.nvim",
        lazy = true,
        enabled = c_sharp,
        ft = "cs"
    },

    -- fuzzy search
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        opts = {
            -- ongoing issue: https://github.com/nvim-telescope/telescope.nvim/issues/2712
            defaults = {
                path_display = { "truncate" }
            }
        }

    },
    -- git
    {
        "lewis6991/gitsigns.nvim",
        opts = {},
        tag = "v0.9.0",
        lazy = true,
        event = "VeryLazy"
    },

    {
        "tpope/vim-fugitive",
        lazy = true,
        event = "VeryLazy",
        dependencies = {
            -- enable Gbrowse
            "tpope/vim-rhubarb", -- with Github
            -- "cedarbaum/fugitive-azure-devops.vim", -- with ADO
        }
    },
    {
        "mhartington/formatter.nvim",
        enabled = true,
        config = function(_)
            require('formatter').setup {
                filetype = {
                    typescript = {
                        require("formatter.filetypes.typescript").prettier,
                    },
                }
            }

            local function prettier()
                local cwd = vim.uv.cwd()
                local dir = vim.fn.finddir('.git', '.;' .. env.home)

                vim.uv.chdir(dir .. '/..')
                print(vim.uv.cwd())
                vim.api.nvim_exec2("!git diff HEAD --name-only | xargs prettier -w", {})
                vim.uv.chdir(cwd)
            end

            vim.api.nvim_create_user_command("P", prettier, { bang = false })
        end,
        init = function()
            vim.keymap.set('n', '<leader><leader>f', ':Format<CR>')
        end
    },
    {
        'windwp/nvim-ts-autotag',
        opts = {},
    },
    {
        'ellisonleao/gruvbox.nvim',
        priority = 1000,
        init = function()
            vim.cmd("colorscheme gruvbox")
        end,
        opts = {
            palette_overrides = {
              dark0_hard = "#000000",
            },
            contrast = "hard", -- can be "hard", "soft" or empty string
        }
    }, { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    {
        "lambdalisue/fern.vim",
        dependencies = {
            "lambdalisue/vim-fern-hijack",
            "yuki-yano/fern-preview.vim"
        },
        init = function()
            vim.cmd([[
                function! s:fern_settings() abort
                  nmap <silent> <buffer> p     <Plug>(fern-action-preview:toggle)
                  nmap <silent> <buffer> <C-p> <Plug>(fern-action-preview:auto:toggle)
                  nmap <silent> <buffer> <C-d> <Plug>(fern-action-preview:scroll:down:half)
                  nmap <silent> <buffer> <C-u> <Plug>(fern-action-preview:scroll:up:half)
                endfunction

                augroup fern-settings
                  autocmd!
                  autocmd FileType fern call s:fern_settings()
                augroup END
            ]]);
        end
    }
}

return packages
