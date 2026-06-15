if vim.b.share_loaded then return end
vim.b.share_loaded = true

local share = require("share")
local key = (share.opts() or {}).keymap
if key == false or key == nil then return end

vim.keymap.set("n", key, function() return share.operator() end,
  { buffer = true, expr = true, desc = "Share qf entries (operator)" })
vim.keymap.set("n", key .. key:sub(-1), function() share.current_line() end,
  { buffer = true, desc = "Share current qf entry" })
vim.keymap.set("x", key, function() share.visual() end,
  { buffer = true, desc = "Share selected qf entries" })
