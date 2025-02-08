return {
  {
    'echasnovski/mini.nvim',
    enabled = true,
    config = function()
      require "mini.ai".setup()
      require "mini.operators".setup()
      require 'mini.statusline'.setup {
        use_icons = true
      }
      require 'mini.surround'.setup()
    end
  },
}
