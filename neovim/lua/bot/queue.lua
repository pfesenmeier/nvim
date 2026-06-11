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

local function queue_entry(path, range, lines, ft)
  vim.ui.input({ prompt = "Note (empty for none, <esc> to cancel): " }, function(note)
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

function M.queue_line()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ""
  queue_entry(path, tostring(lnum), { line }, vim.bo[buf].filetype)
end

function M.queue_visual()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  -- line("v") = visual anchor, line(".") = cursor; both valid mid-visual.
  -- The `<`/`>` marks aren't set until visual mode ends.
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  local lstart, lend = math.min(a, b), math.max(a, b)
  local lines = vim.api.nvim_buf_get_lines(buf, lstart - 1, lend, false)
  local range = lstart == lend and tostring(lstart) or (lstart .. "-" .. lend)
  -- Exit visual so the ui.input prompt isn't behind a visual highlight.
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  queue_entry(path, range, lines, vim.bo[buf].filetype)
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
