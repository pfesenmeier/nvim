local M = {}

-- Tunables; bot.init.setup() overwrites these from user opts.
M.submit_delay_ms = 100
M.ready_min_lines = 5
M.ready_stable_ms = 500
M.ready_tick_ms = 100
M.ready_timeout_ms = 5000

-- \x1b[200~...\x1b[201~ is bracketed paste; the TUI treats the whole
-- block as one paste rather than line-by-line submits.
function M.paste(buf, content)
  local job = vim.b[buf].terminal_job_id
  if not job then
    vim.notify("bot: buffer has no terminal job", vim.log.levels.WARN)
    return false
  end
  vim.api.nvim_chan_send(job, "\x1b[200~" .. content .. "\x1b[201~")
  return true
end

-- Submit in a separate chansend so the TUI's input loop processes the
-- paste-close before seeing \r.
function M.submit(buf)
  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local j = vim.b[buf].terminal_job_id
    if j then vim.api.nvim_chan_send(j, "\r") end
  end, M.submit_delay_ms)
end

-- Polls the buffer until it has at least `ready_min_lines` non-empty lines
-- and that count has been stable for `ready_stable_ms`. Then invokes cb.
-- Mirrors the readiness heuristic in CodeCompanion / sidekick.nvim.
function M.wait_until_ready(buf, cb)
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
    if non_empty >= M.ready_min_lines and (waited - stable_since) >= M.ready_stable_ms then
      cb()
      return
    end
    if waited >= M.ready_timeout_ms then
      vim.notify("bot: terminal readiness timed out — sending anyway", vim.log.levels.WARN)
      cb()
      return
    end
    waited = waited + M.ready_tick_ms
    vim.defer_fn(tick, M.ready_tick_ms)
  end
  vim.defer_fn(tick, M.ready_tick_ms)
end

return M
