return {
  {
    'echasnovski/mini.nvim',
    enabled = true,
    config = function()
      require "mini.ai".setup()
      require "mini.bufremove".setup()
      require 'mini.statusline'.setup {
        use_icons = true
      }
      -- require 'mini.surround'.setup()
      require 'mini.files'.setup()

      vim.keymap.set('n', '<leader>m', function() require('mini.files').open() end, {})
    end
  },
}
