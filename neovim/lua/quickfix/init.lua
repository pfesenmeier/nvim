local M = {}

local ns = vim.api.nvim_create_namespace("quickfix-flash")
local hl = vim.hl or vim.highlight

local function flash(bufnr, s_lnum, s_col, e_lnum, e_col)
  if not hl or not vim.api.nvim_buf_is_valid(bufnr) then return end
  pcall(hl.range, bufnr, ns, "IncSearch",
    { s_lnum - 1, math.max(0, s_col - 1) },
    { e_lnum - 1, e_col },
    { timeout = 250 })
end

local function flash_qf_current()
  local idx = vim.fn.getqflist({ idx = 0 }).idx
  if idx == 0 then return end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == 'quickfix' then
      flash(buf, idx, 1, idx, -1)
    end
  end
end

local function clamp_col(lnum, col)
  local line = vim.fn.getline(lnum) or ""
  local max = #line
  if col < 1 then col = 1 end
  if col > max + 1 then col = max + 1 end
  return col
end

local function add_range(s_lnum, s_col, e_lnum, e_col)
  if s_lnum < 1 then return end
  if s_lnum > e_lnum or (s_lnum == e_lnum and s_col > e_col) then
    s_lnum, s_col, e_lnum, e_col = e_lnum, e_col, s_lnum, s_col
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local text = (vim.api.nvim_buf_get_lines(bufnr, s_lnum - 1, s_lnum, false)[1]) or ""
  vim.fn.setqflist({{
    bufnr    = bufnr,
    lnum     = s_lnum,
    col      = clamp_col(s_lnum, s_col),
    end_lnum = e_lnum,
    end_col  = clamp_col(e_lnum, e_col + 1),
    text     = text,
  }}, 'a')
  local title = vim.fn.getqflist({ title = 1 }).title
  vim.notify(("qf: +1 → %s"):format(title ~= "" and title or "(no title)"))
  flash(bufnr, s_lnum, clamp_col(s_lnum, s_col), e_lnum, clamp_col(e_lnum, e_col + 1))
end

_G._qf_add_opfunc = function(_motion_type)
  local s = vim.api.nvim_buf_get_mark(0, "[")
  local e = vim.api.nvim_buf_get_mark(0, "]")
  add_range(s[1], s[2] + 1, e[1], e[2] + 1)
end

function M.operator()
  vim.o.operatorfunc = "v:lua._qf_add_opfunc"
  return "g@"
end

function M.visual()
  local s = vim.fn.getpos("'<")
  local e = vim.fn.getpos("'>")
  add_range(s[2], s[3], e[2], e[3])
end

function M.new_list()
  vim.ui.input({ prompt = "QF list title: " }, function(name)
    if not name or name == "" then return end
    vim.fn.setqflist({}, ' ', { title = name, items = {} })
    vim.notify(("qf: new list '%s'"):format(name))
  end)
end

function M.list_goto(target)
  local last = vim.fn.getqflist({ nr = '$' }).nr
  if last == 0 then
    vim.notify("qf: no lists", vim.log.levels.WARN)
    return
  end
  local cur = vim.fn.getqflist({ nr = 0 }).nr
  if target == 'first' then
    if cur > 1 then vim.cmd((cur - 1) .. 'colder') end
  elseif target == 'last' then
    if cur < last then vim.cmd((last - cur) .. 'cnewer') end
  elseif target == 'prev' then
    pcall(vim.cmd, 'colder')
  elseif target == 'next' then
    pcall(vim.cmd, 'cnewer')
  end
  vim.schedule(flash_qf_current)
end

function M.pick_lists()
  local last = vim.fn.getqflist({ nr = '$' }).nr
  if last == 0 then
    vim.notify("qf: no lists", vim.log.levels.WARN)
    return
  end
  local current = vim.fn.getqflist({ nr = 0 }).nr
  local items = {}
  for nr = 1, last do
    local info = vim.fn.getqflist({ nr = nr, title = 1, size = 1 })
    local marker = nr == current and "*" or " "
    items[#items + 1] = {
      nr = nr,
      text = ("%s #%d  %s  (%d)"):format(
        marker, nr,
        (info.title ~= "" and info.title) or "(no title)",
        info.size
      ),
    }
  end
  MiniPick.start({
    source = {
      name = "Quickfix lists",
      items = items,
      choose = function(item)
        if not item then return end
        local full = vim.fn.getqflist({ nr = item.nr, all = 1 })
        vim.fn.setqflist({}, 'r', {
          items   = full.items,
          title   = full.title,
          context = full.context,
        })
        vim.schedule(function()
          vim.cmd('copen')
          flash_qf_current()
        end)
      end,
    },
  })
end

return M
