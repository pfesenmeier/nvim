local terminal = require("bot.terminal")

local M = {}

local function queue_path()
  local dir = vim.fn.stdpath("data") .. "/bot"
  vim.fn.mkdir(dir, "p")
  local cwd = vim.fn.getcwd()
  local slug = cwd:gsub("/", "%%")
  return dir .. "/" .. slug .. ".md"
end

local function relative_path(path)
  if path == "" then return "[No Name]" end
  local cwd = vim.fn.getcwd()
  if vim.startswith(path, cwd .. "/") then
    return path:sub(#cwd + 2)
  end
  return path
end

-- Builds the fenced-code chat payload used by both queue entries and
-- review code-actions ("chat about this").
function M.format_block(path, range, lines, ft, note)
  local header = string.format("## %s:%s\n", relative_path(path), range)
  local note_line = (note and note ~= "") and ("> " .. note .. "\n") or ""
  local fence = string.format("```%s\n%s\n```\n\n", ft, table.concat(lines, "\n"))
  return header .. note_line .. fence
end

local hl_ns = vim.api.nvim_create_namespace("bot_queue_hl")

-- Highlight a region while the note prompt is open. `region` is either
-- {kind="line", lstart, lend} or {kind="char", l0, c0, l1, c1} (1-indexed
-- rows, 0-indexed cols, end col exclusive). Returns a clear function.
local function highlight_region(buf, region)
  if region.kind == "char" then
    vim.api.nvim_buf_set_extmark(buf, hl_ns, region.l0 - 1, region.c0, {
      end_row = region.l1 - 1,
      end_col = region.c1,
      hl_group = "Visual",
    })
  else
    vim.api.nvim_buf_set_extmark(buf, hl_ns, region.lstart - 1, 0, {
      end_row = region.lend,
      hl_group = "Visual",
      hl_eol = true,
    })
  end
  vim.cmd("redraw")
  return function() vim.api.nvim_buf_clear_namespace(buf, hl_ns, 0, -1) end
end

local function queue_entry(path, range, lines, ft, clear_hl)
  vim.ui.input({ prompt = "Note (empty for none, <esc> to cancel): " }, function(note)
    if clear_hl then clear_hl() end
    if note == nil then return end
    local block = M.format_block(path, range, lines, ft, note)
    local f, err = io.open(queue_path(), "a")
    if not f then
      vim.notify("bot: cannot open queue: " .. (err or "?"), vim.log.levels.ERROR)
      return
    end
    f:write(block)
    f:close()
  end)
end

local function range_string(lstart, lend)
  return lstart == lend and tostring(lstart) or (lstart .. "-" .. lend)
end

function M.queue_line()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ""
  local clear_hl = highlight_region(buf, { kind = "line", lstart = lnum, lend = lnum })
  queue_entry(path, tostring(lnum), { line }, vim.bo[buf].filetype, clear_hl)
end

function M.queue_motion(motion_type)
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  local ft = vim.bo[buf].filetype
  local l0, c0 = unpack(vim.api.nvim_buf_get_mark(buf, "["))
  local l1, c1 = unpack(vim.api.nvim_buf_get_mark(buf, "]"))
  local lines, region
  if motion_type == "char" then
    -- nvim_buf_get_mark cols are 0-indexed; `]` end col is inclusive.
    -- Clamp end col to the line length so EOL motions don't blow up.
    local last = vim.api.nvim_buf_get_lines(buf, l1 - 1, l1, false)[1] or ""
    local end_col = math.min(c1 + 1, #last)
    lines = vim.api.nvim_buf_get_text(buf, l0 - 1, c0, l1 - 1, end_col, {})
    region = { kind = "char", l0 = l0, c0 = c0, l1 = l1, c1 = end_col }
  else
    lines = vim.api.nvim_buf_get_lines(buf, l0 - 1, l1, false)
    region = { kind = "line", lstart = l0, lend = l1 }
  end
  local clear_hl = highlight_region(buf, region)
  queue_entry(path, range_string(l0, l1), lines, ft, clear_hl)
end

function M.operator()
  vim.go.operatorfunc = "v:lua.require'bot.queue'.queue_motion"
  return "g@"
end

function M.queue_visual()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  -- line("v") = visual anchor, line(".") = cursor; both valid mid-visual.
  -- The `<`/`>` marks aren't set until visual mode ends.
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  local lstart, lend = math.min(a, b), math.max(a, b)
  local lines = vim.api.nvim_buf_get_lines(buf, lstart - 1, lend, false)
  local range = range_string(lstart, lend)
  -- Exit visual so the ui.input prompt gets focus. feedkeys is async, so
  -- schedule the prompt to run after the <Esc> has been processed.
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  local ft = vim.bo[buf].filetype
  vim.schedule(function()
    local clear_hl = highlight_region(buf, { kind = "line", lstart = lstart, lend = lend })
    queue_entry(path, range, lines, ft, clear_hl)
  end)
end

function M.edit_queue()
  vim.cmd.edit(vim.fn.fnameescape(queue_path()))
end

local function read_queue()
  local f = io.open(queue_path(), "r")
  if not f then return "" end
  local content = f:read("*a") or ""
  f:close()
  return content
end

local function clear_queue()
  local f = io.open(queue_path(), "w")
  if f then f:close() end
end

function M.send_and_clear()
  local content = read_queue()
  if content == "" then
    vim.notify("bot: queue is empty", vim.log.levels.INFO)
    return
  end

  local choice = vim.fn.confirm("Send queue and clear?", "&Yes\n&No", 2)
  if choice ~= 1 then return end

  require("bot").send_to_terminal(content, { submit = true, on_sent = clear_queue })
end

return M
