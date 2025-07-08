local M = {}
local opts = { noremap = true, silent = true }

local function show_next_term(o)
  o = o or {}
  local prev = o.prev or false
  local current = vim.api.nvim_get_current_buf()
  local current_is_term = vim.bo.buftype == "terminal"

  local terms = {}
  for _, value in ipairs(vim.api.nvim_list_bufs()) do
    local type = vim.bo[value].buftype

    if type == "terminal" then
      table.insert(terms, value)
    end
  end

  if #terms == 0 then
    vim.print("no terminal buffers found")
    return
  end

  if #terms == 1 and current_is_term then
    vim.print("no other terminal buffers found")
    return
  end

  if not current_is_term then
    vim.api.nvim_set_current_buf(terms[1])
    return
  end

  local indexOf = nil

  for index, value in ipairs(terms) do
    if value == current then
      indexOf = index
      break
    end
  end

  local nextIndex = indexOf % #terms + 1

  if prev then
    if indexOf == 1 then
      nextIndex = #terms
    else
      nextIndex = indexOf - 1
    end
  end

  local next_buf = terms[nextIndex]

  vim.api.nvim_set_current_buf(next_buf)
end

M.setup = function()
  vim.keymap.set("n", "<leader>t", show_next_term, opts)
  vim.keymap.set("n", "<leader>T", function() show_next_term({ prev = true }) end, opts)
  vim.keymap.set('t', '<Esc><Esc>', [[<c-\><C-N>]])
end

return M
