local formatters = require("share.formatters")

local M = {}

local defaults = {
  keymap   = "gy",
  format = {
    dispatch   = nil,
    formatters = {},
    wrap       = nil,
  },
}

local opts = defaults

function M.setup(user)
  opts = vim.tbl_deep_extend("force", defaults, user or {})
end

function M.opts()
  return opts
end

local function default_dispatch(item)
  if item._kind then return item._kind end
  if item.type and item.type ~= "" then return "diagnostic" end
  local ud = type(item.user_data) == "table" and item.user_data or nil
  if ud and (ud.severity or ud.message) then return "diagnostic" end
  if ud and ud.lsp then return "lsp_ref" end
  if item.text and item.text:match("^[EWIN] │ ") then return "diagnostic" end
  return "location"
end

function M.yank(items, register)
  if not items or #items == 0 then
    vim.notify("share: no qf entries in range", vim.log.levels.WARN)
    return
  end

  local dispatch = opts.format.dispatch or default_dispatch
  local builtins = formatters
  local overrides = opts.format.formatters or {}
  local cache = {}
  local parts = {}

  for _, item in ipairs(items) do
    local name = dispatch(item) or "location"
    local fn = overrides[name] or builtins[name] or builtins.location
    parts[#parts + 1] = fn(item, opts, cache)
  end

  local body = table.concat(parts, "\n\n")
  if opts.format.wrap then body = opts.format.wrap(body, items) end

  local reg = register or vim.v.register
  vim.fn.setreg(reg, body)
  vim.notify(("Shared %d entr%s → @%s"):format(#items, #items == 1 and "y" or "ies", reg == "" and '"' or reg))
end

local function slice_qf(s, e)
  local list = vim.fn.getqflist()
  if s > e then s, e = e, s end
  s = math.max(1, s)
  e = math.min(#list, e)
  local out = {}
  for i = s, e do out[#out + 1] = list[i] end
  return out
end

_G._share_opfunc = function(motion_type)
  local s = vim.api.nvim_buf_get_mark(0, "[")[1]
  local e = vim.api.nvim_buf_get_mark(0, "]")[1]
  M.yank(slice_qf(s, e))
end

function M.operator()
  vim.o.operatorfunc = "v:lua._share_opfunc"
  return "g@"
end

function M.visual()
  local s = vim.fn.getpos("'<")[2]
  local e = vim.fn.getpos("'>")[2]
  M.yank(slice_qf(s, e))
end

function M.current_line()
  local line = vim.fn.line(".")
  M.yank(slice_qf(line, line))
end

-- Synthesize qf-shaped items from a buffer range so the existing formatters
-- (default dispatch → "location") can pretty-print them without ever touching
-- the quickfix list. If any diagnostics fall in the range, emit those instead
-- (toqflist sets `type`, so default dispatch routes to the diagnostic formatter).
local function buffer_items(s_lnum, e_lnum)
  if s_lnum > e_lnum then s_lnum, e_lnum = e_lnum, s_lnum end
  local bufnr = vim.api.nvim_get_current_buf()

  local items = {{
    _kind    = "range",
    bufnr    = bufnr,
    lnum     = s_lnum,
    end_lnum = e_lnum,
  }}

  local diags = {}
  for _, d in ipairs(vim.diagnostic.get(bufnr)) do
    local lnum = d.lnum + 1
    if lnum >= s_lnum and lnum <= e_lnum then
      diags[#diags + 1] = d
    end
  end
  table.sort(diags, function(a, b)
    if a.lnum ~= b.lnum then return a.lnum < b.lnum end
    return (a.col or 0) < (b.col or 0)
  end)
  for _, qf in ipairs(vim.diagnostic.toqflist(diags)) do
    items[#items + 1] = qf
  end
  return items
end

_G._share_buf_opfunc = function(_motion_type)
  local s = vim.api.nvim_buf_get_mark(0, "[")[1]
  local e = vim.api.nvim_buf_get_mark(0, "]")[1]
  M.yank(buffer_items(s, e))
end

function M.buffer_operator()
  vim.o.operatorfunc = "v:lua._share_buf_opfunc"
  return "g@"
end

function M.buffer_visual()
  local s = vim.fn.getpos("'<")[2]
  local e = vim.fn.getpos("'>")[2]
  M.yank(buffer_items(s, e))
end

return M
