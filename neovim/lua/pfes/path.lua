local env = require('pfes.env')
local M = {}

---@param ... string
---@return string
function M.pathjoin(...)
  local sep = nil

  if env.islinux then
    sep = "/"
  else
    sep = "\\"
  end

  local result = ""
  for _, value in ipairs({ ... }) do
    if result == "" then
      result = result .. value
    else
      result = result .. sep .. value
    end
  end

  return result
end

return M
