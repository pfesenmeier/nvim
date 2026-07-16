vim.keymap.set('n', '<F6>', function()
  require "osv".run_this(require "osv".run_this())
end, { buffer = 0 })

Config.later(function()
  local dap = require("dap")
  dap.configurations.lua = {
    {
      type = 'nlua',
      request = 'attach',
      name = "Attach to running Neovim instance",
    }
  }

  dap.adapters.nlua = function(callback, config)
    callback({ type = 'server', host = config.host or "127.0.0.1", port = config.port or 8086 })
  end
end)
