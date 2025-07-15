return {
  {
    'echasnovski/mini.nvim',
    enabled = true,
    config = function()
      local gen_spec = require('mini.ai').gen_spec
      require "mini.ai".setup({
        custom_textobjects = {
          -- Function definition (needs treesitter queries with these captures)
          F = gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
          o = gen_spec.treesitter({
            a = { '@conditional.outer', '@loop.outer' },
            i = { '@conditional.inner', '@loop.inner' },
          })
        }
      })
      require "mini.bufremove".setup()
      require 'mini.statusline'.setup {
        use_icons = true
      }

      vim.api.nvim_create_user_command("Bd", function()
        require('mini.bufremove').delete()
      end, {})
      -- require 'mini.surround'.setup()
      require 'mini.files'.setup()
      require 'mini.starter'.setup()
      require 'mini.pick'.setup({
        mappings = {
          choose_marked = "<C-y>",
        }
      })
      require 'mini.move'.setup()

      -- for codecompanion
      local diff = require("mini.diff")
      diff.setup({
        -- Disabled by default
        source = diff.gen_source.none(),
      })

      vim.keymap.set('n', '<leader>m', function() require('mini.files').open() end, {})
    end
  },
}
