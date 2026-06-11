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

M.opts = defaults

-- Shared send path used by queue + review. Opens the terminal if needed,
-- waits until ready, pastes `content`, optionally submits and runs on_sent.
function M.send_to_terminal(content, send_opts)
  send_opts = send_opts or {}
  local submit = send_opts.submit ~= false
  local on_sent = send_opts.on_sent

  if not M.opts.get_terminal then
    vim.notify("bot: no get_terminal configured", vim.log.levels.ERROR)
    return
  end

  local terminal = require("bot.terminal")

  local function deliver(buf)
    if not terminal.paste(buf, content) then return end
    if submit then terminal.submit(buf) end
    if on_sent then on_sent() end
  end

  local buf = M.opts.get_terminal()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    deliver(buf)
    return
  end

  if not M.opts.open_terminal then
    vim.notify("bot: terminal not open and no open_terminal configured", vim.log.levels.WARN)
    return
  end
  local opened = M.opts.open_terminal()
  if not opened or not vim.api.nvim_buf_is_valid(opened) then
    vim.notify("bot: open_terminal did not return a valid buffer", vim.log.levels.ERROR)
    return
  end
  terminal.wait_until_ready(opened, function() deliver(opened) end)
end

function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", defaults, user_opts or {})

  local terminal = require("bot.terminal")
  terminal.submit_delay_ms = M.opts.submit_delay_ms
  terminal.ready_min_lines = M.opts.ready_min_lines
  terminal.ready_stable_ms = M.opts.ready_stable_ms
  terminal.ready_tick_ms = M.opts.ready_tick_ms
  terminal.ready_timeout_ms = M.opts.ready_timeout_ms

  local queue = require("bot.queue")
  local prefix = M.opts.prefix

  vim.keymap.set("n", prefix .. "b", queue.queue_line, { desc = "Bot: queue current line" })
  vim.keymap.set("x", prefix, queue.queue_visual, { desc = "Bot: queue visual selection" })
  vim.keymap.set("n", prefix .. "e", queue.edit_queue, { desc = "Bot: edit queue" })
  vim.keymap.set("n", prefix .. "x", queue.send_and_clear, { desc = "Bot: send and clear queue" })
  vim.keymap.set("n", prefix .. "a", function()
    require("bot.review").code_action()
  end, { desc = "Bot: review action at cursor" })

  local ok, miniclue = pcall(require, "mini.clue")
  if ok and miniclue.config and miniclue.config.clues then
    table.insert(miniclue.config.clues, { mode = "n", keys = prefix, desc = "+bot" })
    table.insert(miniclue.config.clues, { mode = "n", keys = prefix .. "b", desc = "Queue current line" })
    table.insert(miniclue.config.clues, { mode = "n", keys = prefix .. "e", desc = "Edit queue" })
    table.insert(miniclue.config.clues, { mode = "n", keys = prefix .. "x", desc = "Send and clear" })
    table.insert(miniclue.config.clues, { mode = "n", keys = prefix .. "a", desc = "Review action at cursor" })
  end
end

return M
