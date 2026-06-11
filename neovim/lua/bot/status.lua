local M = { state = "idle" }

function M.set(s)
  M.state = s
  vim.api.nvim_exec_autocmds("User", { pattern = "BotStatusChanged" })
  vim.cmd("redrawstatus")
end

-- Empty string when idle so the statusline section vanishes; mini.statusline
-- treats falsy/empty sections as absent.
function M.component()
  if M.state == "idle" then return "" end
  local icon = ({ working = "⏳", ["needs-input"] = "🔔" })[M.state] or ""
  return icon .. " claude"
end

return M
