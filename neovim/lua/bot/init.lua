local M = {}

local defaults = {
  prefix = "gb",
  -- function(): integer|nil  — return a live terminal buffer, or nil if none.
  get_terminal = nil,
  -- function(): integer|nil  — start the terminal and return its buffer.
  open_terminal = nil,
  -- Readiness poll tuning (used only after a fresh open).
  ready_min_lines = 5,
  ready_stable_ms = 500,
  ready_tick_ms = 100,
  ready_timeout_ms = 5000,
  -- Delay between the bracketed-paste block and the trailing \r submit.
  -- Without this, the TUI sees them in the same input cycle and treats the
  -- \r as part of the paste rather than a submit.
  submit_delay_ms = 100,
}

local opts = defaults

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

local function queue_entry(path, range, lines, ft)
  vim.ui.input({ prompt = "Note (empty for none, <esc> to cancel): " }, function(note)
    if note == nil then return end

    local header = string.format("## %s:%s\n", relative_path(path), range)
    local note_line = note ~= "" and ("> " .. note .. "\n") or ""
    local fence = string.format("```%s\n%s\n```\n\n", ft, table.concat(lines, "\n"))
    local block = header .. note_line .. fence

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

local function send_payload(buf, content)
  local job = vim.b[buf].terminal_job_id
  if not job then
    vim.notify("bot: buffer has no terminal job", vim.log.levels.WARN)
    return false
  end
  -- \x1b[200~...\x1b[201~ is bracketed paste; the TUI treats the whole
  -- block as one paste rather than line-by-line submits.
  vim.api.nvim_chan_send(job, "\x1b[200~" .. content .. "\x1b[201~")
  -- Submit in a separate chansend so the TUI's input loop processes the
  -- paste-close before seeing \r.
  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local j = vim.b[buf].terminal_job_id
    if j then vim.api.nvim_chan_send(j, "\r") end
  end, opts.submit_delay_ms)
  return true
end

-- Polls the buffer until it has at least `ready_min_lines` non-empty lines
-- and that line count has been stable for `ready_stable_ms`. Then invokes cb.
-- Mirrors the readiness heuristic in CodeCompanion / sidekick.nvim.
local function wait_until_ready(buf, cb)
  local last_count, stable_since, waited = -1, nil, 0
  local function tick()
    if not vim.api.nvim_buf_is_valid(buf) then
      vim.notify("bot: terminal buffer became invalid", vim.log.levels.ERROR)
      return
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local non_empty = 0
    for _, l in ipairs(lines) do
      if l ~= "" then non_empty = non_empty + 1 end
    end
    if non_empty ~= last_count then
      last_count = non_empty
      stable_since = waited
    end
    if non_empty >= opts.ready_min_lines and (waited - stable_since) >= opts.ready_stable_ms then
      cb()
      return
    end
    if waited >= opts.ready_timeout_ms then
      vim.notify("bot: terminal readiness timed out — sending anyway", vim.log.levels.WARN)
      cb()
      return
    end
    waited = waited + opts.ready_tick_ms
    vim.defer_fn(tick, opts.ready_tick_ms)
  end
  vim.defer_fn(tick, opts.ready_tick_ms)
end

function M.send_and_clear()
  local content = read_queue()
  if content == "" then
    vim.notify("bot: queue is empty", vim.log.levels.INFO)
    return
  end
  if not opts.get_terminal then
    vim.notify("bot: no get_terminal configured", vim.log.levels.ERROR)
    return
  end

  local choice = vim.fn.confirm("Send queue and clear?", "&Yes\n&No", 2)
  if choice ~= 1 then return end

  local buf = opts.get_terminal()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    if send_payload(buf, content) then clear_queue() end
    return
  end

  if not opts.open_terminal then
    vim.notify("bot: terminal not open and no open_terminal configured", vim.log.levels.WARN)
    return
  end
  local opened = opts.open_terminal()
  if not opened or not vim.api.nvim_buf_is_valid(opened) then
    vim.notify("bot: open_terminal did not return a valid buffer", vim.log.levels.ERROR)
    return
  end
  wait_until_ready(opened, function()
    if send_payload(opened, content) then clear_queue() end
  end)
end

function M.setup(user_opts)
  opts = vim.tbl_deep_extend("force", defaults, user_opts or {})

  vim.keymap.set("n", opts.prefix .. "b", M.queue_line, { desc = "Bot: queue current line" })
  vim.keymap.set("x", opts.prefix, M.queue_visual, { desc = "Bot: queue visual selection" })
  vim.keymap.set("n", opts.prefix .. "e", M.edit_queue, { desc = "Bot: edit queue" })
  vim.keymap.set("n", opts.prefix .. "x", M.send_and_clear, { desc = "Bot: send and clear queue" })

  local ok, miniclue = pcall(require, "mini.clue")
  if ok and miniclue.config and miniclue.config.clues then
    table.insert(miniclue.config.clues, { mode = "n", keys = opts.prefix, desc = "+bot" })
    table.insert(miniclue.config.clues, { mode = "n", keys = opts.prefix .. "b", desc = "Queue current line" })
    table.insert(miniclue.config.clues, { mode = "n", keys = opts.prefix .. "e", desc = "Edit queue" })
    table.insert(miniclue.config.clues, { mode = "n", keys = opts.prefix .. "x", desc = "Send and clear" })
  end
end

return M
