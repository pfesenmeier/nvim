-- Setup calls for custom libraries under neovim/lua/.
-- Add new modules here rather than creating a per-module plugin/ file.

require("floatterm").setup({
  terminals = {
    claude = { key = "c", cmd = "claude" },
    jjui   = { key = "j", cmd = "jjui"  },
    shell  = { key = "s", cmd = nil     },
  },
  order = { "claude", "jjui", "shell" },
})

require("remote").setup()
require("share").setup({})
require("workspace").setup({})
