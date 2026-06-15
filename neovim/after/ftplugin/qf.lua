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

vim.keymap.set("n", "dd", function()
  local cur   = vim.fn.getqflist({ items = 1, title = 1, context = 1 })
  local items = cur.items
  local i     = vim.fn.line(".")
  if i < 1 or i > #items then return end
  table.remove(items, i)
  vim.fn.setqflist({}, 'r', { items = items, title = cur.title, context = cur.context })
  if #items > 0 then
    vim.api.nvim_win_set_cursor(0, { math.min(i, #items), 0 })
  end
end, { buffer = true, desc = "Delete qf entry" })
